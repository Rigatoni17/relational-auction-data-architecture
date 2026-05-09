<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,java.util.*,java.math.BigDecimal,com.buyme.auth.Db,com.buyme.auction.AuctionService" %>

<%
Integer userId = (Integer)session.getAttribute("userId");
String role = (String)session.getAttribute("role");

if (userId == null) {
    response.sendRedirect("login.jsp");
    return;
}

String flash = (String)session.getAttribute("flash");
if (flash != null) session.removeAttribute("flash");

Connection conn = null;
List<Map<String,Object>> myAuctions = new ArrayList<>();
List<Map<String,Object>> myBids = new ArrayList<>();
List<Map<String,Object>> outbidList = new ArrayList<>();
List<String> notifications = new ArrayList<>();
int activeCount = 0;

try {
    conn = Db.get();
    AuctionService.ensureExpiredAuctionsProcessed(conn);
    
    // User's auctions (for sellers)
    if ("seller".equals(role)) {
        try(PreparedStatement ps = conn.prepareStatement(
            "SELECT a.auction_id, i.name, a.current_price, a.end_time, a.status " +
            "FROM auctions a JOIN items i ON a.item_id = i.item_id " +
            "WHERE a.seller_id = ? ORDER BY a.end_time ASC LIMIT 5")) {
            ps.setInt(1, userId);
            try(ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String,Object> auc = new HashMap<>();
                    auc.put("id", rs.getInt("auction_id"));
                    auc.put("name", rs.getString("name"));
                    auc.put("price", rs.getBigDecimal("current_price"));
                    auc.put("endTime", rs.getTimestamp("end_time"));
                    auc.put("status", rs.getString("status"));
                    myAuctions.add(auc);
                }
            }
        }
    }
    
    // User's bids (for buyers)
    if ("buyer".equals(role)) {
        try(PreparedStatement ps = conn.prepareStatement(
            "SELECT DISTINCT a.auction_id, i.name, a.current_price, a.high_bidder_id, a.status, a.end_time " +
            "FROM bids b JOIN auctions a ON b.auction_id = a.auction_id " +
            "JOIN items i ON a.item_id = i.item_id " +
            "WHERE b.user_id = ? ORDER BY a.end_time ASC LIMIT 5")) {
            ps.setInt(1, userId);
            try(ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String,Object> bid = new HashMap<>();
                    bid.put("id", rs.getInt("auction_id"));
                    bid.put("name", rs.getString("name"));
                    bid.put("price", rs.getBigDecimal("current_price"));
                    bid.put("leading", rs.getInt("high_bidder_id") == userId);
                    bid.put("status", rs.getString("status"));
                    bid.put("endTime", rs.getTimestamp("end_time"));
                    myBids.add(bid);
                }
            }
        }

        // Outbid notifications (active only)
        try(PreparedStatement ps = conn.prepareStatement(
            "SELECT DISTINCT a.auction_id, i.name, a.current_price, a.end_time " +
            "FROM bids b JOIN auctions a ON b.auction_id = a.auction_id " +
            "JOIN items i ON a.item_id = i.item_id " +
            "WHERE b.user_id = ? AND a.status='active' AND a.high_bidder_id <> ? " +
            "ORDER BY a.end_time ASC LIMIT 5")) {
            ps.setInt(1, userId);
            ps.setInt(2, userId);
            try(ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String,Object> ob = new HashMap<>();
                    ob.put("id", rs.getInt("auction_id"));
                    ob.put("name", rs.getString("name"));
                    ob.put("price", rs.getBigDecimal("current_price"));
                    ob.put("endTime", rs.getTimestamp("end_time"));
                    outbidList.add(ob);
                }
            }
        }

        // Winner notifications for recently closed auctions
        try(PreparedStatement ps = conn.prepareStatement(
            "SELECT i.name, a.closing_price FROM auctions a " +
            "JOIN items i ON a.item_id=i.item_id " +
            "WHERE a.winner_id=? AND a.status='closed' AND a.end_time >= DATE_SUB(NOW(), INTERVAL 7 DAY) " +
            "ORDER BY a.end_time DESC LIMIT 3")) {
            ps.setInt(1, userId);
            try(ResultSet rs=ps.executeQuery()){
                while(rs.next()){
                    notifications.add("You won " + rs.getString("name") +
                        " for $" + rs.getBigDecimal("closing_price"));
                }
            }
        }
    }

    // Active auctions count
    try(PreparedStatement ps = conn.prepareStatement("SELECT COUNT(*) FROM auctions WHERE status = 'active'")) {
        try(ResultSet rs = ps.executeQuery()) {
            if (rs.next()) activeCount = rs.getInt(1);
        }
    }

    // Seller notifications: closed without meeting reserve in last 7 days
    if ("seller".equals(role)) {
        try(PreparedStatement ps = conn.prepareStatement(
            "SELECT i.name FROM auctions a JOIN items i ON a.item_id=i.item_id " +
            "WHERE a.seller_id=? AND a.status='closed' AND a.reserve_met=0 AND a.end_time >= DATE_SUB(NOW(), INTERVAL 7 DAY) " +
            "ORDER BY a.end_time DESC LIMIT 3")) {
            ps.setInt(1, userId);
            try(ResultSet rs=ps.executeQuery()){
                while(rs.next()){
                    notifications.add("Reserve not met on " + rs.getString("name"));
                }
            }
        }
    }
    
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Dashboard - BuyMe Auctions</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0;padding:20px}
    .container{max-width:1200px;margin:0 auto}
    header{background:#1f3c88;color:#fff;padding:24px;border-radius:12px}
    header h1{margin:0;font-size:32px}
    .stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px;margin:24px 0}
    .stat-card{background:#fff;border-radius:10px;padding:20px;box-shadow:0 4px 12px rgba(16,24,40,0.08);text-align:center}
    .stat-number{font-size:36px;font-weight:700;color:#1f3c88}
    .stat-label{font-size:14px;color:#666;text-transform:uppercase;letter-spacing:0.5px}
    .notif{padding:12px 16px;border-radius:10px;background:#e0f2ff;color:#083f75;margin:18px 0;box-shadow:0 4px 12px rgba(16,24,40,0.06)}
    .notif ul{margin:8px 0 0;padding-left:20px}
    .nav-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px;margin:32px 0}
    .nav-card{background:#fff;border-radius:12px;padding:24px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    .nav-card h3{margin-top:0;color:#1f3c88;border-bottom:2px solid #1f3c88;padding-bottom:12px}
    .nav-btn{display:block;width:90%;max-width:340px;padding:14px;margin:10px auto;background:#1f3c88;color:white;text-decoration:none;
             border-radius:8px;font-size:16px;font-weight:600;text-align:center}
    .nav-btn:hover{background:#1e40af}
    .auction-list{max-height:300px;overflow-y:auto}
    .auction-item{padding:12px;border-bottom:1px solid #edf2f7}
    .auction-item:last-child{border-bottom:none}
    .auction-name{font-weight:600;font-size:15px;margin:0 0 4px;display:block}
    .auction-meta{font-size:13px;color:#666}
    .flash{padding:16px;border-radius:8px;margin:20px 0}
    .flash.success{background:#e6f7ed;color:#0b6b37}
    .flash.error{background:#fde8e8;color:#a81515}
    @media(max-width:768px){.stats-grid,.nav-grid{grid-template-columns:1fr}}
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>🏪 BuyMe Dashboard</h1>
      <p style="margin:4px 0 0;font-size:16px;color:#bfe4ff">
        Welcome back! <%= activeCount %> active auctions
      </p>
    </header>

    <% if (flash != null) { %>
      <div class="flash success"><%= flash %></div>
    <% } %>
    <% if (!notifications.isEmpty()) { %>
      <div class="notif">
        <strong>Notifications</strong>
        <ul>
          <% for(String note : notifications){ %>
            <li><%= note %></li>
          <% } %>
        </ul>
      </div>
    <% } %>

    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-number"><%= activeCount %></div>
        <div class="stat-label">Active Auctions</div>
      </div>
      <div class="stat-card">
        <div class="stat-number"><%= "seller".equals(role) ? myAuctions.size() : myBids.size() %></div>
        <div class="stat-label"><%= "seller".equals(role) ? "Your Auctions" : "Your Bids" %></div>
      </div>
    </div>

    <div class="nav-grid">
      
      <!-- BUYER SECTION -->
      <% if ("buyer".equals(role)) { %>
      <div class="nav-card">
        <h3>Buyer Actions</h3>
        <a href="browse.jsp" class="nav-btn">🛒 Browse Marketplace</a>
        <a href="search.jsp" class="nav-btn">🔍 Search Auctions</a>
        <a href="questions.jsp" class="nav-btn">💬 Questions & Answers</a>
        <a href="my-bids.jsp" class="nav-btn">📂 View My Bids</a>
        <a href="alerts.jsp" class="nav-btn">🔔 My Alerts</a>
        <% if (!myBids.isEmpty()) { %>
          <h4 style="margin:20px 0 8px;font-size:16px">Your Bids (<%= myBids.size() %>)</h4>
          <div class="auction-list">
            <% for (Map<String,Object> bid : myBids) { %>
            <div class="auction-item">
              <a href="auction.jsp?id=<%= bid.get("id") %>" class="auction-name">
                <%= bid.get("name") %>
              </a>
              <div class="auction-meta">
                $<%= ((BigDecimal)bid.get("price")).setScale(2) %> • 
                <%= ((Boolean)bid.get("leading")) ? "✅ Leading" : "⚠️  Outbid" %> • 
                <%= bid.get("status") %>
              </div>
            </div>
            <% } %>
          </div>
        <% } %>
        <% if (!outbidList.isEmpty()) { %>
          <h4 style="margin:18px 0 8px;font-size:16px;color:#b91c1c">Outbid Alerts</h4>
          <div class="auction-list">
            <% for (Map<String,Object> ob : outbidList) { %>
            <div class="auction-item">
              <a href="auction.jsp?id=<%= ob.get("id") %>" class="auction-name">
                <%= ob.get("name") %>
              </a>
              <div class="auction-meta">
                Current: $<%= ((BigDecimal)ob.get("price")).setScale(2) %> • Ends: <%= ob.get("endTime") %>
              </div>
            </div>
            <% } %>
          </div>
        <% } %>
      </div>
      
      <!-- SELLER SECTION -->  
      <% } else if ("seller".equals(role)) { %>
      <div class="nav-card">
        <h3>Seller Actions</h3>
        <a href="create-auction.jsp" class="nav-btn">➕ Create Auction</a>
        <a href="browse.jsp" class="nav-btn">👀 Monitor Market</a>
        <a href="questions.jsp" class="nav-btn">💬 Questions & Answers</a>
        <a href="my-auctions.jsp" class="nav-btn">📦 View My Auctions</a>
        <% if (!myAuctions.isEmpty()) { %>
          <h4 style="margin:20px 0 8px;font-size:16px">Your Auctions (<%= myAuctions.size() %>)</h4>
          <div class="auction-list">
            <% for (Map<String,Object> auc : myAuctions) { %>
            <div class="auction-item">
              <a href="auction.jsp?id=<%= auc.get("id") %>" class="auction-name">
                <%= auc.get("name") %>
              </a>
              <div class="auction-meta">
                $<%= ((BigDecimal)auc.get("price")).setScale(2) %> • 
                <%= auc.get("status") %>
              </div>
            </div>
            <% } %>
          </div>
        <% } %>
      </div>
      
      <!-- REP SECTION -->
      <% } else if ("rep".equals(role)) { %>
      <div class="nav-card">
        <h3>Rep Tools</h3>
        <a href="answers.jsp" class="nav-btn">💬 Answer Questions</a>
        <a href="rep-tools.jsp" class="nav-btn">🛠️ Moderation Console</a>
        <a href="questions.jsp" class="nav-btn">📋 All Questions</a>
      </div>
      
      <!-- ADMIN SECTION -->
      <% } else if ("admin".equals(role)) { %>
      <div class="nav-card">
        <h3>Admin Dashboard</h3>
        <a href="admin.jsp" class="nav-btn">📊 Sales Reports</a>
        <a href="rep-tools.jsp" class="nav-btn">👥 Manage Reps</a>
        <a href="browse.jsp" class="nav-btn">👀 Platform Overview</a>
      </div>
      <% } %>
      
      <!-- COMMON LINKS -->
      <div class="nav-card">
        <h3>Quick Links</h3>
        <a href="logout" class="nav-btn">🚪 Logout</a>
        <a href="questions.jsp" class="nav-btn">💬 Q&A</a>
        <a href="search.jsp" class="nav-btn">🔍 Search</a>
      </div>
      
    </div>
  </div>
</main>
</body>
</html>
<%
} catch (Exception e) {
    out.println("<p style='color:red'>Error: " + e.getMessage() + "</p>");
} finally {
    if (conn != null) try { conn.close(); } catch (Exception ignore) {}
}
%>
