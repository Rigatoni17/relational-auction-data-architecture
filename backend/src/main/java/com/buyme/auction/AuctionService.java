package com.buyme.auction;

import java.math.BigDecimal;
import java.sql.*;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

/**
 * Utility class encapsulating all auction/bidding mutations so servlets can stay light.
 */
public final class AuctionService {
  private static final BigDecimal MIN_MANUAL_INCREMENT = new BigDecimal("1.00");

  private AuctionService() {}

  public static void ensureExpiredAuctionsProcessed(Connection conn) throws Exception {
    final List<Integer> toClose = new ArrayList<>();
    try (PreparedStatement ps = conn.prepareStatement(
        "SELECT auction_id FROM auctions WHERE status='active' AND end_time <= NOW()")) {
      try (ResultSet rs = ps.executeQuery()) {
        while (rs.next()) {
          toClose.add(rs.getInt(1));
        }
      }
    }
    for (Integer id : toClose) {
      runInTransaction(conn, () -> {
        AuctionSnapshot auction = lockAuction(conn, id);
        if (auction == null || auction.isClosed()) {
          return;
        }
        resolveAutoBids(conn, id);
        finalizeAuction(conn, auction);
      });
    }
  }

  public static void createAuction(Connection conn, int sellerId, String itemName, String description,
                                   String category, BigDecimal startPrice, BigDecimal reservePrice,
                                   Timestamp endTime) throws Exception {
    if (itemName == null || itemName.isBlank()) {
      throw new IllegalArgumentException("Item name is required.");
    }
    if (startPrice == null || startPrice.compareTo(BigDecimal.ZERO) <= 0) {
      throw new IllegalArgumentException("Start price must be positive.");
    }
    if (reservePrice != null && reservePrice.compareTo(startPrice) < 0) {
      throw new IllegalArgumentException("Reserve cannot be lower than start price.");
    }
    if (endTime == null || endTime.toInstant().isBefore(Instant.now().plus(1, ChronoUnit.HOURS))) {
      throw new IllegalArgumentException("End time must be at least one hour from now.");
    }

    runInTransaction(conn, () -> {
      int itemId;
      try (PreparedStatement ps = conn.prepareStatement(
          "INSERT INTO items(seller_id,name,description,category) VALUES (?,?,?,?)",
          Statement.RETURN_GENERATED_KEYS)) {
        ps.setInt(1, sellerId);
        ps.setString(2, itemName.trim());
        ps.setString(3, description);
        ps.setString(4, category);
        ps.executeUpdate();
        try (ResultSet keys = ps.getGeneratedKeys()) {
          if (!keys.next()) throw new SQLException("Failed to create item");
          itemId = keys.getInt(1);
        }
      }

      try (PreparedStatement ps = conn.prepareStatement(
          "INSERT INTO auctions(item_id,seller_id,start_price,reserve_price,current_price,start_time,end_time,status) "
              + "VALUES(?,?,?,?,?,?,?, 'active')")) {
        ps.setInt(1, itemId);
        ps.setInt(2, sellerId);
        ps.setBigDecimal(3, startPrice);
        if (reservePrice == null) ps.setNull(4, Types.DECIMAL); else ps.setBigDecimal(4, reservePrice);
        ps.setBigDecimal(5, startPrice);
        ps.setTimestamp(6, Timestamp.from(Instant.now()));
        ps.setTimestamp(7, endTime);
        ps.executeUpdate();
      }
    });
  }

  public static void placeManualBid(Connection conn, int auctionId, int userId, BigDecimal amount) throws Exception {
    if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
      throw new IllegalArgumentException("Bid amount must be positive.");
    }
    runInTransaction(conn, () -> {
      AuctionSnapshot auction = lockAuction(conn, auctionId);
      if (auction == null) throw new IllegalArgumentException("Auction not found.");
      if (auction.isClosed() || auction.endTime().before(Timestamp.from(Instant.now()))) {
        throw new IllegalArgumentException("Auction already closed.");
      }
      if (auction.sellerId == userId) {
        throw new IllegalArgumentException("Sellers cannot bid on their own auctions.");
      }
      BigDecimal current = auction.currentPrice != null ? auction.currentPrice : auction.startPrice;
      BigDecimal minimum = current.add(MIN_MANUAL_INCREMENT);
      if (amount.compareTo(minimum) < 0) {
        throw new IllegalArgumentException("Bid must be at least " + minimum);
      }
      insertBid(conn, auctionId, userId, amount, false);
      resolveAutoBids(conn, auctionId);
    });
  }

  public static void registerAutoBid(Connection conn, int auctionId, int userId, BigDecimal maxAmount,
                                     BigDecimal increment) throws Exception {
    if (maxAmount == null || maxAmount.compareTo(BigDecimal.ZERO) <= 0) {
      throw new IllegalArgumentException("Max amount must be positive.");
    }
    if (increment == null || increment.compareTo(new BigDecimal("0.50")) < 0) {
      throw new IllegalArgumentException("Increment must be at least 0.50.");
    }
    runInTransaction(conn, () -> {
      AuctionSnapshot auction = lockAuction(conn, auctionId);
      if (auction == null) throw new IllegalArgumentException("Auction not found.");
      if (auction.isClosed() || auction.endTime().before(Timestamp.from(Instant.now()))) {
        throw new IllegalArgumentException("Auction already closed.");
      }
      if (auction.sellerId == userId) {
        throw new IllegalArgumentException("Sellers cannot use auto-bid on their own auctions.");
      }
      try (PreparedStatement ps = conn.prepareStatement(
          "INSERT INTO auto_bids(auction_id,user_id,max_amount,increment) VALUES(?,?,?,?) "
              + "ON DUPLICATE KEY UPDATE max_amount=VALUES(max_amount), increment=VALUES(increment)")) {
        ps.setInt(1, auctionId);
        ps.setInt(2, userId);
        ps.setBigDecimal(3, maxAmount);
        ps.setBigDecimal(4, increment);
        ps.executeUpdate();
      }
      resolveAutoBids(conn, auctionId);
    });
  }

  public static void closeAuction(Connection conn, int auctionId, int sellerId) throws Exception {
    runInTransaction(conn, () -> {
      AuctionSnapshot auction = lockAuction(conn, auctionId);
      if (auction == null) throw new IllegalArgumentException("Auction not found.");
      if (auction.sellerId != sellerId) {
        throw new IllegalArgumentException("Only the seller can close the auction.");
      }
      if (auction.isClosed()) return;
      resolveAutoBids(conn, auctionId);
      finalizeAuction(conn, auction);
    });
  }

  private static void finalizeAuction(Connection conn, AuctionSnapshot auction) throws SQLException {
    BidSnapshot winning = fetchWinningBid(conn, auction.auctionId);
    Integer winnerId = null;
    BigDecimal closingPrice = null;
    boolean reserveMet = false;
    if (winning != null) {
      boolean met = auction.reservePrice == null
          || winning.amount.compareTo(auction.reservePrice) >= 0;
      if (met) {
        winnerId = winning.userId;
        closingPrice = winning.amount;
        reserveMet = true;
      }
    }
    try (PreparedStatement ps = conn.prepareStatement(
        "UPDATE auctions SET status='closed', winner_id=?, closing_price=?, reserve_met=?, updated_at=NOW() "
            + "WHERE auction_id=?")) {
      if (winnerId == null) ps.setNull(1, Types.INTEGER); else ps.setInt(1, winnerId);
      if (closingPrice == null) ps.setNull(2, Types.DECIMAL); else ps.setBigDecimal(2, closingPrice);
      ps.setBoolean(3, reserveMet);
      ps.setInt(4, auction.auctionId);
      ps.executeUpdate();
    }
  }

  private static void resolveAutoBids(Connection conn, int auctionId) throws SQLException {
    final List<AutoBid> watchers = new ArrayList<>();
    try (PreparedStatement ps = conn.prepareStatement(
        "SELECT user_id,max_amount,increment FROM auto_bids WHERE auction_id=? "
            + "ORDER BY max_amount DESC, created_at ASC")) {
      ps.setInt(1, auctionId);
      try (ResultSet rs = ps.executeQuery()) {
        while (rs.next()) {
          watchers.add(new AutoBid(rs.getInt(1), rs.getBigDecimal(2), rs.getBigDecimal(3)));
        }
      }
    }
    if (watchers.isEmpty()) return;

    boolean placed;
    do {
      BidSnapshot current = readCurrentSnapshot(conn, auctionId);
      BigDecimal currentAmount = current.amount;
      Integer leader = current.userId;
      placed = false;
      for (AutoBid watcher : watchers) {
        if (watcher.userId == leader) continue;
        if (watcher.maxAmount.compareTo(currentAmount) <= 0) continue;
        BigDecimal next = currentAmount.add(watcher.increment);
        if (next.compareTo(watcher.maxAmount) > 0) next = watcher.maxAmount;
        if (next.compareTo(currentAmount) > 0) {
          insertBid(conn, auctionId, watcher.userId, next, true);
          placed = true;
          break;
        }
      }
    } while (placed);
  }

  private static void insertBid(Connection conn, int auctionId, int userId,
                                BigDecimal amount, boolean auto) throws SQLException {
    try (PreparedStatement ps = conn.prepareStatement(
        "INSERT INTO bids(auction_id,user_id,amount,is_auto) VALUES(?,?,?,?)")) {
      ps.setInt(1, auctionId);
      ps.setInt(2, userId);
      ps.setBigDecimal(3, amount);
      ps.setBoolean(4, auto);
      ps.executeUpdate();
    }
    try (PreparedStatement ps = conn.prepareStatement(
        "UPDATE auctions SET current_price=?, high_bidder_id=?, updated_at=NOW() WHERE auction_id=?")) {
      ps.setBigDecimal(1, amount);
      ps.setInt(2, userId);
      ps.setInt(3, auctionId);
      ps.executeUpdate();
    }
  }

  private static AuctionSnapshot lockAuction(Connection conn, int auctionId) throws SQLException {
    try (PreparedStatement ps = conn.prepareStatement(
        "SELECT auction_id,seller_id,status,start_price,current_price,reserve_price,end_time "
            + "FROM auctions WHERE auction_id=? FOR UPDATE")) {
      ps.setInt(1, auctionId);
      try (ResultSet rs = ps.executeQuery()) {
        if (!rs.next()) return null;
        return new AuctionSnapshot(
            rs.getInt("auction_id"),
            rs.getInt("seller_id"),
            rs.getString("status"),
            rs.getBigDecimal("start_price"),
            rs.getBigDecimal("current_price"),
            rs.getBigDecimal("reserve_price"),
            rs.getTimestamp("end_time"));
      }
    }
  }

  private static BidSnapshot fetchWinningBid(Connection conn, int auctionId) throws SQLException {
    try (PreparedStatement ps = conn.prepareStatement(
        "SELECT user_id,amount FROM bids WHERE auction_id=? ORDER BY amount DESC, bid_time ASC LIMIT 1")) {
      ps.setInt(1, auctionId);
      try (ResultSet rs = ps.executeQuery()) {
        if (!rs.next()) return null;
        return new BidSnapshot(rs.getInt(1), rs.getBigDecimal(2));
      }
    }
  }

  private static BidSnapshot readCurrentSnapshot(Connection conn, int auctionId) throws SQLException {
    try (PreparedStatement ps = conn.prepareStatement(
        "SELECT COALESCE(current_price,start_price) AS amount, high_bidder_id "
            + "FROM auctions WHERE auction_id=?")) {
      ps.setInt(1, auctionId);
      try (ResultSet rs = ps.executeQuery()) {
        if (!rs.next()) throw new SQLException("Auction missing for snapshot: " + auctionId);
        BigDecimal amt = rs.getBigDecimal("amount");
        int leader = rs.getInt("high_bidder_id");
        if (rs.wasNull()) leader = -1;
        return new BidSnapshot(leader, amt);
      }
    }
  }

  private static void runInTransaction(Connection conn, TxBody body) throws Exception {
    boolean initial = conn.getAutoCommit();
    conn.setAutoCommit(false);
    try {
      body.run();
      conn.commit();
    } catch (Exception ex) {
      conn.rollback();
      throw ex;
    } finally {
      conn.setAutoCommit(initial);
    }
  }

  private record AuctionSnapshot(int auctionId, int sellerId, String status,
                                 BigDecimal startPrice, BigDecimal currentPrice,
                                 BigDecimal reservePrice, Timestamp endTime) {
    boolean isClosed() {
      return "closed".equalsIgnoreCase(status);
    }
  }

  private record BidSnapshot(int userId, BigDecimal amount) {}

  private record AutoBid(int userId, BigDecimal maxAmount, BigDecimal increment) {}

  @FunctionalInterface
  private interface TxBody {
    void run() throws Exception;
  }
}
