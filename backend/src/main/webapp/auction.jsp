<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,java.time.*,java.time.format.DateTimeFormatter,java.util.*,java.math.BigDecimal,com.buyme.auth.Db,com.buyme.auction.AuctionService" %>

<%
Integer userId = (Integer)session.getAttribute("userId");
if(userId==null){ 
    String requested = request.getRequestURI() + (request.getQueryString() != null ? "?" + request.getQueryString() : "");
    session = request.getSession(true);
    session.setAttribute("redirectAfterLogin", requested);
    response.sendRedirect("login.jsp"); 
    return; 
}

String role = (String)session.getAttribute("role");

String flashSuccess = (String)session.getAttribute("flashSuccess");
String flashError = (String)session.getAttribute("flashError");
if(flashSuccess!=null) session.removeAttribute("flashSuccess");
if(flashError!=null) session.removeAttribute("flashError");

String idParam = request.getParameter("id");
if(idParam==null){
  response.sendRedirect("dashboard.jsp");
  return;
}

int auctionId = Integer.parseInt(idParam);

String itemName=null, category=null, description=null, sellerName=null, winnerName=null, highBidderName=null, status=null;
BigDecimal startPrice=null, currentPrice=null, reservePrice=null, closingPrice=null;
Timestamp endTime=null;
boolean reserveMet=false;
int sellerId=-1;
List<Map<String,Object>> bids = new ArrayList<>();
List<Map<String,Object>> watchers = new ArrayList<>();
Map<String,Object> myAuto = null;
List<Map<String,Object>> similarItems = new ArrayList<>();

Connection conn=null;
try{
  conn=Db.get();
  AuctionService.ensureExpiredAuctionsProcessed(conn);
  
  // Main auction details
  try(PreparedStatement ps=conn.prepareStatement(
    "SELECT a.*, i.name AS item_name,i.description,i.category, s.username AS seller_name, " +
    "w.username AS winner_name, h.username AS high_name " +
    "FROM auctions a JOIN items i ON a.item_id=i.item_id " +
    "JOIN users s ON a.seller_id=s.user_id " +
    "LEFT JOIN users w ON a.winner_id=w.user_id " +
    "LEFT JOIN users h ON a.high_bidder_id=h.user_id WHERE a.auction_id=?")){
    ps.setInt(1,auctionId);
    try(ResultSet rs=ps.executeQuery()){
      if(!rs.next()){
        out.println("<p class='error'>Auction not found.</p>");
      } else {
        status=rs.getString("status");
        itemName=rs.getString("item_name");
        category=rs.getString("category");
        description=rs.getString("description");
        sellerName=rs.getString("seller_name");
        winnerName=rs.getString("winner_name");
        highBidderName=rs.getString("high_name");
        startPrice=rs.getBigDecimal("start_price");
        currentPrice=rs.getBigDecimal("current_price");
        reservePrice=rs.getBigDecimal("reserve_price");
        closingPrice=rs.getBigDecimal("closing_price");
        endTime=rs.getTimestamp("end_time");
        sellerId=rs.getInt("seller_id");
        reserveMet=rs.getBoolean("reserve_met");
      }
    }
  }

  // Bid history
  try(PreparedStatement ps=conn.prepareStatement(
    "SELECT u.username,b.amount,b.is_auto,b.bid_time FROM bids b JOIN users u ON b.user_id=u.user_id " +
    "WHERE b.auction_id=? ORDER BY b.bid_time DESC")){
    ps.setInt(1,auctionId);
    try(ResultSet rs=ps.executeQuery()){
      while(rs.next()){
        Map<String,Object> row=new HashMap<>();
        row.put("user", rs.getString("username"));
        row.put("amount", rs.getBigDecimal("amount"));
        row.put("auto", rs.getBoolean("is_auto"));
        row.put("time", rs.getTimestamp("bid_time").toLocalDateTime());
        bids.add(row);
      }
    }
  }

  // Auto bidders
  try(PreparedStatement ps=conn.prepareStatement(
    "SELECT u.username,ab.max_amount,ab.increment,ab.user_id FROM auto_bids ab JOIN users u ON ab.user_id=u.user_id WHERE ab.auction_id=? ORDER BY ab.max_amount DESC")){
    ps.setInt(1,auctionId);
    try(ResultSet rs=ps.executeQuery()){
      while(rs.next()){
        Map<String,Object> row=new HashMap<>();
        row.put("user", rs.getString("username"));
        row.put("max", rs.getBigDecimal("max_amount"));
        row.put("increment", rs.getBigDecimal("increment"));
        row.put("userId", rs.getInt("user_id"));
        if((Integer)row.get("userId")==userId){
          myAuto=row;
        }
        watchers.add(row);
      }
    }
  }

  // SIMILAR ITEMS - FIXED NULL-SAFE
  if (category != null) {
    try(PreparedStatement ps=conn.prepareStatement(
      "SELECT a.auction_id, i.name, i.category, a.closing_price, a.end_time, a.reserve_met, u.username AS seller_name " +
      "FROM auctions a JOIN items i ON a.item_id=i.item_id " +
      "JOIN users u ON a.seller_id=u.user_id " +
      "WHERE i.category = ? AND a.status = 'closed' " +
      "AND a.end_time > DATE_SUB(NOW(), INTERVAL 30 DAY) " +
      "ORDER BY a.end_time DESC LIMIT 5")){
      ps.setString(1, category);
      try(ResultSet rs=ps.executeQuery()){
        while(rs.next()){
          Map<String,Object> row=new HashMap<>();
          row.put("auctionId", rs.getInt("auction_id"));
          row.put("name", rs.getString("name"));
          row.put("closingPrice", rs.getBigDecimal("closing_price"));
          row.put("endTime", rs.getTimestamp("end_time"));
          row.put("reserveMet", rs.getBoolean("reserve_met"));
          row.put("sellerName", rs.getString("seller_name"));
          similarItems.add(row);
        }
      }
    }
  }

}catch(Exception e){
  out.println("<p class='error'>Unable to load auction: "+e.getMessage()+"</p>");
}finally{
  if(conn!=null) try{ conn.close(); } catch(Exception ignore){}
}

if(status==null){
  response.sendRedirect("dashboard.jsp");
  return;
}

boolean closed = "closed".equalsIgnoreCase(status);
boolean isSeller = "seller".equals(role) && userId==sellerId;
boolean canBid = !isSeller && !closed;

DateTimeFormatter dtFmt = DateTimeFormatter.ofPattern("MMM d, yyyy h:mm a");
Duration timeLeft = endTime==null?Duration.ZERO:Duration.between(Instant.now(), endTime.toInstant());
%>

<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title><%= itemName %> - Auction</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    header{background:#1f3c88;color:#fff;padding:20px}
    header h1{margin:0;font-size:24px}
    .meta{margin-top:6px;font-size:14px;color:#dfe3ff}
    .container{max-width:980px;margin:28px auto;padding:0 20px}
    .panel{background:#fff;border-radius:10px;padding:20px;margin-bottom:22px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    .panel h3{margin-top:0}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}
    label{display:block;margin:10px 0 4px;font-weight:600;font-size:13px}
    input[type=number],textarea{width:100%;padding:10px;border:1px solid #ccd5e0;border-radius:6px;background:#fbfdff;font-size:14px}
    textarea{min-height:90px}
    button{margin-top:12px;padding:10px 16px;border:none;border-radius:6px;background:#1f3c88;color:#fff;font-size:14px}
    table{width:100%;border-collapse:collapse;font-size:14px;margin-top:10px}
    th,td{padding:9px;text-align:left;border-bottom:1px solid #edf0f6}
    th{background:#f0f4ff;color:#4b5d7c;text-transform:uppercase;font-size:12px}
    .flash{padding:12px;border-radius:6px;margin-bottom:18px}
    .flash.success{background:#e6f7ed;color:#0b6b37}
    .flash.error{background:#fde8e8;color:#a81515}
    .badge{padding:4px 10px;border-radius:999px;font-size:12px;text-transform:uppercase}
    .badge.active{background:#e0f2ff;color:#03539c}
    .badge.closed{background:#ffe5e5;color:#9c032c}
    .note{font-size:13px;color:#555;margin-top:8px}
    .similar-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px}
    .similar-item{background:#f8fbff;border:1px solid #e1e8ff;border-radius:8px;padding:16px}
    .similar-name{font-weight:600;font-size:15px;margin:0 0 6px;display:block}
    .similar-meta{font-size:12px;color:#666}
  </style>
</head>
<body>
<header>
  <h1><%= itemName==null?"Auction":itemName %></h1>
  <div class="meta">
    Seller: <%= sellerName %> &nbsp;|&nbsp;
    Status: <span class="badge <%= closed?"closed":"active" %>"><%= status %></span> &nbsp;|&nbsp;
    Ends: <%= endTime==null?"---":dtFmt.format(endTime.toInstant().atZone(ZoneId.systemDefault())) %>
  </div>
</header>

<main class="container">
  <% if(flashSuccess!=null){ %>
    <div class="flash success"><%= flashSuccess %></div>
  <% } %>
  <% if(flashError!=null){ %>
    <div class="flash error"><%= flashError %></div>
  <% } %>

  <section class="panel">
    <h3>Item details</h3>
    <p class="note"><%= description==null?"No description provided.":description %></p>
    <p class="note">Category: <strong><%= category==null?"---":category %></strong></p>
    <p class="note">Reserve price: <strong><%= reservePrice==null?"---":"$"+reservePrice %></strong></p>
    <p class="note">Current price: <strong>$<%= currentPrice==null?startPrice:currentPrice %></strong></p>
    <% if(!closed){ %>
      <p class="note">Time left: <strong><%= timeLeft.isNegative()?"Closing soon":timeLeft.toHoursPart()+"h "+timeLeft.toMinutesPart()+"m" %></strong></p>
    <% } else { %>
      <p class="note">Closing price: <strong><%= closingPrice==null?"Reserve not met":"$"+closingPrice %></strong></p>
      <p class="note">
        Winner: <strong><%= winnerName==null?"No winner":winnerName %></strong>
        (<%= reserveMet ? "Reserve was met" : "Reserve not met" %>)
      </p>
    <% } %>
    <% if(!closed && highBidderName!=null){ %>
      <p class="note">Leading bidder: <strong><%= highBidderName %></strong></p>
    <% } %>
    
    <% if ("buyer".equals(role) || "seller".equals(role)) { %>
    <p class="note">
      <a href="questions.jsp?forAuction=<%= auctionId %>">Ask a question about this item</a>
    </p>
    <% } %>
  </section>

  <% if(canBid){ %>
  <section class="grid">
    <div class="panel">
      <h3>Place a manual bid</h3>
      <form method="post" action="${pageContext.request.contextPath}/bid">
        <input type="hidden" name="auctionId" value="<%= auctionId %>">
        <label>Amount
          <input type="number" step="0.01" name="amount" placeholder="Enter your bid" required>
        </label>
        <button type="submit">Submit bid</button>
      </form>
    </div>
    <div class="panel">
      <h3>Automatic bidding</h3>
      <% if(myAuto!=null){ %>
        <p class="note">Current limit: $<%= myAuto.get("max") %> (+<%= myAuto.get("increment") %>)</p>
      <% } %>
      <form method="post" action="${pageContext.request.contextPath}/auto-bid">
        <input type="hidden" name="auctionId" value="<%= auctionId %>">
        <label>Maximum willing amount
          <input type="number" step="0.01" name="maxAmount" required>
        </label>
        <label>Bid increment
          <input type="number" step="0.50" name="increment" required>
        </label>
        <button type="submit">Save auto bid</button>
      </form>
    </div>
  </section>
  <% } else if(isSeller && !closed){ %>
    <div class="panel">
      <h3>Seller actions</h3>
      <form method="post" action="${pageContext.request.contextPath}/seller/close">
        <input type="hidden" name="auctionId" value="<%= auctionId %>">
        <button type="submit">Close auction now</button>
      </form>
      <p class="note">Closing will immediately pick the top bidder if the reserve is met.</p>
    </div>
  <% } %>

  <section class="panel">
    <h3>Bid history</h3>
    <table>
      <tr><th>Bidder</th><th>Amount</th><th>When</th><th>Type</th></tr>
      <% if(bids.isEmpty()){ %>
        <tr><td colspan="4">No bids yet. Be the first!</td></tr>
      <% } else {
        for(Map<String,Object> row : bids){
      %>
        <tr>
          <td><%= row.get("user") %></td>
          <td>$<%= row.get("amount") %></td>
          <td><%= dtFmt.format(((LocalDateTime)row.get("time")).atZone(ZoneId.systemDefault())) %></td>
          <td><%= Boolean.TRUE.equals(row.get("auto")) ? "Auto" : "Manual" %></td>
        </tr>
      <% }} %>
    </table>
  </section>

  <% if(isSeller){ %>
  <section class="panel">
    <h3>Auto-bid watchers</h3>
    <table>
      <tr><th>User</th><th>Upper limit</th><th>Increment</th></tr>
      <% if(watchers.isEmpty()){ %>
        <tr><td colspan="3">No auto-bidders registered.</td></tr>
      <% } else {
        for(Map<String,Object> row : watchers){
      %>
        <tr>
          <td><%= row.get("user") %></td>
          <td>$<%= row.get("max") %></td>
          <td>$<%= row.get("increment") %></td>
        </tr>
      <% }} %>
    </table>
  </section>
  <% } %>

  <!-- SIMILAR ITEMS SECTION - FIXED NULL-SAFE -->
  <% if (!similarItems.isEmpty()) { %>
  <section class="panel">
    <h3>Similar items (last 30 days)</h3>
    <div class="similar-grid">
      <% for (Map<String,Object> item : similarItems) { %>
      <div class="similar-item">
        <div class="similar-name"><%= item.get("name") %> 
          <span class="badge <%= ((Boolean)item.get("reserveMet")) ? "active" : "closed" %>">
            <%= ((Boolean)item.get("reserveMet")) ? "Sold" : "Reserve not met" %>
          </span>
        </div>
        <div class="similar-meta">
          Seller: <%= item.get("sellerName") %> • 
          Closed: <%= ((Timestamp)item.get("endTime")).toString().substring(0,16) %> • 
          $<% BigDecimal price = (BigDecimal)item.get("closingPrice"); %><%= price != null ? price.setScale(2) : "N/A" %>
        </div>
      </div>
      <% } %>
    </div>
  </section>
  <% } %>

  <div class="panel">
    <a href="dashboard.jsp">← Back to dashboard</a> | 
    <a href="search.jsp">Search auctions</a> | 
    <a href="questions.jsp">Questions & Answers</a>
  </div>
</main>
</body>
</html>
