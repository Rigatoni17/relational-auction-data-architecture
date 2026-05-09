<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,java.util.*,java.math.BigDecimal,com.buyme.auth.Db" %>

<%
Integer userId = (Integer)session.getAttribute("userId");
String role = (String)session.getAttribute("role");

if (userId == null || !"rep".equals(role)) {
    String requested = request.getRequestURI() +
        (request.getQueryString() != null ? "?" + request.getQueryString() : "");
    session = request.getSession(true);
    session.setAttribute("redirectAfterLogin", requested);
    response.sendRedirect("login.jsp");
    return;
}

Connection conn = null;
List<Map<String,Object>> recentUsers = new ArrayList<>();
List<Map<String,Object>> recentBids = new ArrayList<>();
List<Map<String,Object>> recentAuctions = new ArrayList<>();

try {
    conn = Db.get();
    
    // Recent users
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT user_id, username, email, role, created_at FROM users " +
        "ORDER BY created_at DESC LIMIT 10")) {
        try(ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String,Object> user = new HashMap<>();
                user.put("id", rs.getInt("user_id"));
                user.put("username", rs.getString("username"));
                user.put("email", rs.getString("email"));
                user.put("role", rs.getString("role"));
                user.put("createdAt", rs.getTimestamp("created_at"));
                recentUsers.add(user);
            }
        }
    }
    
    // Recent bids
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT b.bid_id, b.auction_id, b.amount, b.bid_time, u.username " +
        "FROM bids b JOIN users u ON b.user_id = u.user_id " +
        "ORDER BY b.bid_time DESC LIMIT 10")) {
        try(ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String,Object> bid = new HashMap<>();
                bid.put("id", rs.getInt("bid_id"));
                bid.put("auctionId", rs.getInt("auction_id"));
                bid.put("amount", rs.getBigDecimal("amount"));
                bid.put("time", rs.getTimestamp("bid_time"));
                bid.put("username", rs.getString("username"));
                recentBids.add(bid);
            }
        }
    }
    
    // Recent auctions
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT a.auction_id, i.name, a.status, a.current_price, a.end_time, u.username AS seller " +
        "FROM auctions a JOIN items i ON a.item_id = i.item_id " +
        "JOIN users u ON a.seller_id = u.user_id " +
        "ORDER BY a.created_at DESC LIMIT 10")) {
        try(ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String,Object> auction = new HashMap<>();
                auction.put("id", rs.getInt("auction_id"));
                auction.put("name", rs.getString("name"));
                auction.put("status", rs.getString("status"));
                auction.put("currentPrice", rs.getBigDecimal("current_price"));
                auction.put("endTime", rs.getTimestamp("end_time"));
                auction.put("seller", rs.getString("seller"));
                recentAuctions.add(auction);
            }
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Rep Tools - BuyMe</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    header{background:#1f3c88;color:#fff;padding:24px}
    header h1{margin:0;font-size:26px}
    .container{max-width:1200px;margin:28px auto;padding:0 20px}
    .tabs{display:flex;gap:8px;margin-bottom:24px}
    .tab{background:#e2e8f0;color:#374151;padding:12px 20px;border-radius:8px 8px 0 0;font-weight:600;
         text-decoration:none;display:block}
    .tab.active{background:#1f3c88;color:white}
    .panel{background:#fff;border-radius:12px;padding:24px;margin-bottom:24px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    .panel h3{margin-top:0;font-size:20px;border-bottom:2px solid #1f3c88;padding-bottom:12px}
    table{width:100%;border-collapse:collapse;font-size:14px}
    th,td{padding:12px 16px;text-align:left;border-bottom:1px solid #edf2f7}
    th{background:#f8faff;color:#374151;font-weight:600;text-transform:uppercase;font-size:12px}
    tr:hover{background:#f8fbff}
    .action-btn{padding:6px 12px;border:none;border-radius:4px;font-size:12px;cursor:pointer;margin-right:4px;text-decoration:none;display:inline-block;line-height:1.4}
    .btn-edit{background:#1f3c88;color:white}
    .btn-delete{background:#dc2626;color:white}
    .badge{padding:4px 8px;border-radius:4px;font-size:11px;text-transform:uppercase;font-weight:600}
    .badge.active{background:#e0f2ff;color:#03539c}
    .badge.closed{background:#fee2e2;color:#dc2626}
    @media(max-width:768px){.tabs{flex-direction:column}}
  </style>
</head>
<body>
<header>
  <h1>🛠️ Rep Moderation Console</h1>
  <p style="margin:4px 0 0;font-size:14px;color:#bfe4ff">Manage users, bids, and auctions</p>
</header>

<main class="container">
  <div class="tabs">
    <a href="#users" class="tab active">Users</a>
    <a href="#bids" class="tab">Recent Bids</a>
    <a href="#auctions" class="tab">Recent Auctions</a>
    <a href="answers.jsp" class="tab">Q&A</a>
  </div>

  <!-- Users -->
  <div class="panel" id="users">
    <h3>Recent Users (<%= recentUsers.size() %>)</h3>
    <% if (recentUsers.isEmpty()) { %>
      <p style="color:#666">No recent users.</p>
    <% } else { %>
      <table>
        <tr><th>Username</th><th>Email</th><th>Role</th><th>Joined</th><th>Actions</th></tr>
        <% for (Map<String,Object> user : recentUsers) { %>
        <tr>
          <td><strong><%= user.get("username") %></strong></td>
          <td><%= user.get("email") %></td>
          <td><span class="badge"><%= user.get("role") %></span></td>
          <td><%= ((Timestamp)user.get("createdAt")).toString().substring(0,16) %></td>
          <td>
            <form method="post" action="${pageContext.request.contextPath}/moderate" style="display:inline">
              <input type="hidden" name="action" value="deleteUser">
              <input type="hidden" name="id" value="<%= user.get("id") %>">
              <button type="submit" class="action-btn btn-delete">Delete</button>
            </form>
          </td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>

  <!-- Recent Bids -->
  <div class="panel" id="bids">
    <h3>Recent Bids (<%= recentBids.size() %>)</h3>
    <% if (recentBids.isEmpty()) { %>
      <p style="color:#666">No recent bids.</p>
    <% } else { %>
      <table>
        <tr><th>Auction ID</th><th>User</th><th>Amount</th><th>Time</th><th>Action</th></tr>
        <% for (Map<String,Object> bid : recentBids) { %>
        <tr>
          <td>#<%= bid.get("auctionId") %></td>
          <td><%= bid.get("username") %></td>
          <td>$<%= ((BigDecimal)bid.get("amount")).setScale(2) %></td>
          <td><%= ((Timestamp)bid.get("time")).toString().substring(0,16) %></td>
          <td>
            <form method="post" action="${pageContext.request.contextPath}/moderate" style="display:inline">
              <input type="hidden" name="action" value="deleteBid">
              <input type="hidden" name="id" value="<%= bid.get("id") %>">
              <button type="submit" class="action-btn btn-delete">Remove</button>
            </form>
          </td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>

  <!-- Recent Auctions -->
  <div class="panel" id="auctions">
    <h3>Recent Auctions (<%= recentAuctions.size() %>)</h3>
    <% if (recentAuctions.isEmpty()) { %>
      <p style="color:#666">No recent auctions.</p>
    <% } else { %>
      <table>
        <tr><th>Auction ID</th><th>Item</th><th>Seller</th><th>Status</th><th>Current</th><th>Actions</th></tr>
        <% for (Map<String,Object> auction : recentAuctions) { %>
        <tr>
          <td>#<%= auction.get("id") %></td>
          <td><%= auction.get("name") %></td>
          <td><%= auction.get("seller") %></td>
          <td><span class="badge <%= "active".equals(auction.get("status")) ? "active" : "closed" %>">
            <%= auction.get("status") %>
          </span></td>
          <td>$<%= ((BigDecimal)auction.get("currentPrice")).setScale(2) %></td>
          <td>
            <form method="post" action="${pageContext.request.contextPath}/moderate" style="display:inline">
              <input type="hidden" name="action" value="deleteAuction">
              <input type="hidden" name="id" value="<%= auction.get("id") %>">
              <button type="submit" class="action-btn btn-delete">Cancel</button>
            </form>
          </td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>

  <div style="text-align:center;margin-top:32px">
    <a href="dashboard.jsp" style="color:#1f3c88;font-weight:600;font-size:16px;text-decoration:none">← Back to Dashboard</a>
  </div>
</main>
</body>
</html>
<%
} catch (Exception e) {
    out.println("<div style='color:red;padding:20px;background:#fee'>Error: " + e.getMessage() + "</div>");
} finally {
    if (conn != null) try { conn.close(); } catch (Exception ignore) {}
}
%>
