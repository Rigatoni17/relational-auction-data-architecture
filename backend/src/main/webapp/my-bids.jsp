<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,java.util.*,java.math.BigDecimal,com.buyme.auth.Db" %>
<%
Integer userId = (Integer)session.getAttribute("userId");
String role = (String)session.getAttribute("role");
if (userId == null || !"buyer".equals(role)) {
    response.sendRedirect("dashboard.jsp");
    return;
}

List<Map<String,Object>> bids = new ArrayList<>();
try (Connection conn = Db.get();
     PreparedStatement ps = conn.prepareStatement(
         "SELECT a.auction_id, i.name, a.current_price, a.high_bidder_id, a.status, a.end_time, " +
         "MAX(b.amount) AS my_amount " +
         "FROM bids b JOIN auctions a ON b.auction_id = a.auction_id " +
         "JOIN items i ON a.item_id = i.item_id " +
         "WHERE b.user_id=? GROUP BY a.auction_id, i.name, a.current_price, a.high_bidder_id, a.status, a.end_time " +
         "ORDER BY a.end_time DESC")) {
    ps.setInt(1, userId);
    try(ResultSet rs = ps.executeQuery()){
        while(rs.next()){
            Map<String,Object> row = new HashMap<>();
            row.put("id", rs.getInt("auction_id"));
            row.put("name", rs.getString("name"));
            row.put("current", rs.getBigDecimal("current_price"));
            row.put("myAmount", rs.getBigDecimal("my_amount"));
            row.put("leading", rs.getInt("high_bidder_id")==userId);
            row.put("status", rs.getString("status"));
            row.put("endTime", rs.getTimestamp("end_time"));
            bids.add(row);
        }
    }
} catch(Exception e){
    out.println("<p style='color:red'>Error loading bids: "+e.getMessage()+"</p>");
}
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>My Bids</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    header{background:#1f3c88;color:#fff;padding:22px}
    header h1{margin:0;font-size:24px}
    .container{max-width:1100px;margin:28px auto;padding:0 20px}
    .card{background:#fff;border-radius:10px;padding:18px;box-shadow:0 6px 18px rgba(16,24,40,0.08);margin-bottom:16px}
    table{width:100%;border-collapse:collapse;font-size:14px}
    th,td{padding:12px;text-align:left;border-bottom:1px solid #edf0f6}
    th{background:#f0f4ff;text-transform:uppercase;font-size:12px;color:#4b5d7c}
    .status-leading{color:#0b6b37;font-weight:700}
    .status-outbid{color:#b91c1c;font-weight:700}
    .back-btn{display:inline-block;margin-top:12px;padding:10px 18px;border-radius:8px;
              background:#1f3c88;color:#fff;text-decoration:none;font-weight:700}
  </style>
</head>
<body>
<header>
  <h1>📂 My Bids</h1>
  <p style="margin:6px 0 0;color:#dfe7ff">Track every auction you have bid on.</p>
</header>
<main class="container">
  <div class="card">
    <% if (bids.isEmpty()) { %>
      <p>You have not placed any bids yet. Browse auctions to get started.</p>
    <% } else { %>
      <table>
        <tr><th>Auction</th><th>My Bid</th><th>Current</th><th>Status</th><th>Ends</th><th></th></tr>
        <% for(Map<String,Object> bid : bids){ %>
        <tr>
          <td><a href="auction.jsp?id=<%= bid.get("id") %>"><%= bid.get("name") %></a></td>
          <td>$<%= ((BigDecimal)bid.get("myAmount")).setScale(2) %></td>
          <td>$<%= ((BigDecimal)bid.get("current")).setScale(2) %></td>
          <td>
            <% if("closed".equals(bid.get("status"))){ %>
              <%= ((Boolean)bid.get("leading")) ? "Won" : "Closed" %>
            <% } else if(((Boolean)bid.get("leading"))){ %>
              <span class="status-leading">Leading</span>
            <% } else { %>
              <span class="status-outbid">Outbid</span>
            <% } %>
          </td>
          <td><%= bid.get("endTime") %></td>
          <td><a href="auction.jsp?id=<%= bid.get("id") %>">Open</a></td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>
  <a class="back-btn" href="dashboard.jsp">← Back to Dashboard</a>
</main>
</body>
</html>
