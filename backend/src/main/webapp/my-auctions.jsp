<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,java.util.*,java.math.BigDecimal,com.buyme.auth.Db" %>
<%
Integer userId = (Integer)session.getAttribute("userId");
String role = (String)session.getAttribute("role");
if (userId == null || !"seller".equals(role)) {
    response.sendRedirect("dashboard.jsp");
    return;
}

List<Map<String,Object>> auctions = new ArrayList<>();
try (Connection conn = Db.get();
     PreparedStatement ps = conn.prepareStatement(
         "SELECT a.auction_id, i.name, a.current_price, a.reserve_price, a.status, a.end_time " +
         "FROM auctions a JOIN items i ON a.item_id=i.item_id " +
         "WHERE a.seller_id=? ORDER BY a.end_time DESC")) {
    ps.setInt(1, userId);
    try(ResultSet rs = ps.executeQuery()){
        while(rs.next()){
            Map<String,Object> row = new HashMap<>();
            row.put("id", rs.getInt("auction_id"));
            row.put("name", rs.getString("name"));
            row.put("current", rs.getBigDecimal("current_price"));
            row.put("reserve", rs.getBigDecimal("reserve_price"));
            row.put("status", rs.getString("status"));
            row.put("endTime", rs.getTimestamp("end_time"));
            auctions.add(row);
        }
    }
} catch(Exception e){
    out.println("<p style='color:red'>Error loading auctions: "+e.getMessage()+"</p>");
}
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>My Auctions</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    header{background:#1f3c88;color:#fff;padding:22px}
    header h1{margin:0;font-size:24px}
    .container{max-width:1100px;margin:28px auto;padding:0 20px}
    .card{background:#fff;border-radius:10px;padding:18px;box-shadow:0 6px 18px rgba(16,24,40,0.08);margin-bottom:16px}
    table{width:100%;border-collapse:collapse;font-size:14px}
    th,td{padding:12px;text-align:left;border-bottom:1px solid #edf0f6}
    th{background:#f0f4ff;text-transform:uppercase;font-size:12px;color:#4b5d7c}
    .badge{padding:4px 8px;border-radius:6px;font-size:12px}
    .badge.active{background:#e0f2ff;color:#03539c}
    .badge.closed{background:#fee2e2;color:#dc2626}
    .back-btn{display:inline-block;margin-top:12px;padding:10px 18px;border-radius:8px;
              background:#1f3c88;color:#fff;text-decoration:none;font-weight:700}
  </style>
</head>
<body>
<header>
  <h1>📦 My Auctions</h1>
  <p style="margin:6px 0 0;color:#dfe7ff">Manage all listings you have created.</p>
</header>
<main class="container">
  <div class="card">
    <% if (auctions.isEmpty()) { %>
      <p>You have not listed any auctions yet. Use the dashboard to create one.</p>
    <% } else { %>
      <table>
        <tr><th>Auction</th><th>Current</th><th>Reserve</th><th>Status</th><th>Ends</th><th></th></tr>
        <% for(Map<String,Object> auc : auctions){ %>
        <tr>
          <td><a href="auction.jsp?id=<%= auc.get("id") %>"><%= auc.get("name") %></a></td>
          <td>$<%= ((BigDecimal)auc.get("current")).setScale(2) %></td>
          <td><%= auc.get("reserve")==null ? "—" : "$"+((BigDecimal)auc.get("reserve")).setScale(2) %></td>
          <td>
            <span class="badge <%= "active".equals(auc.get("status"))?"active":"closed" %>">
              <%= auc.get("status") %>
            </span>
          </td>
          <td><%= auc.get("endTime") %></td>
          <td><a href="auction.jsp?id=<%= auc.get("id") %>">Open</a></td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>
  <a class="back-btn" href="dashboard.jsp">← Back to Dashboard</a>
</main>
</body>
</html>
