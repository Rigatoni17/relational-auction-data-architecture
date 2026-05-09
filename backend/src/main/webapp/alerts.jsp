<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%@ page import="jakarta.servlet.http.*,jakarta.servlet.*,java.util.*,java.sql.*" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>

<%
if (session == null || session.getAttribute("userId") == null) {
    response.sendRedirect("login.jsp"); // redirect to login
    return;
}

// flash messages
String flash = (String) session.getAttribute("flashSuccess");
if (flash != null) { session.removeAttribute("flashSuccess"); }

String error = (String) session.getAttribute("flashError");
if (error != null) { session.removeAttribute("flashError"); }

request.setAttribute("flash", flash);
request.setAttribute("error", error);

// retrieve user's alerts + matches from DB
Integer userId = (Integer) session.getAttribute("userId");
List<Map<String,String>> alertsList = new ArrayList<>();
List<Map<String,Object>> matches = new ArrayList<>();
try (Connection conn = com.buyme.auth.Db.get()) {
    try (PreparedStatement ps = conn.prepareStatement("SELECT alert_id, keyword, category FROM alerts WHERE user_id = ?")) {
        ps.setInt(1, userId);
        try (ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String,String> alert = new HashMap<>();
                alert.put("id", String.valueOf(rs.getInt("alert_id")));
                alert.put("keyword", rs.getString("keyword"));
                alert.put("category", rs.getString("category"));
                alertsList.add(alert);
            }
        }
    }

    // simple matches: active auctions containing keyword or same category
    try (PreparedStatement ps = conn.prepareStatement(
        "SELECT a.auction_id,i.name,i.category,a.current_price,a.end_time " +
        "FROM auctions a JOIN items i ON a.item_id=i.item_id " +
        "WHERE a.status='active' AND (i.name LIKE ? OR i.description LIKE ? OR i.category LIKE ?) " +
        "ORDER BY a.end_time ASC LIMIT 10")) {
        String kw = alertsList.isEmpty() ? "%" : "%" + alertsList.get(0).get("keyword") + "%";
        ps.setString(1, kw);
        ps.setString(2, kw);
        ps.setString(3, alertsList.isEmpty() ? "%" : alertsList.get(0).get("category")+"%");
        try (ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String,Object> row=new HashMap<>();
                row.put("id", rs.getInt("auction_id"));
                row.put("name", rs.getString("name"));
                row.put("category", rs.getString("category"));
                row.put("price", rs.getBigDecimal("current_price"));
                row.put("endTime", rs.getTimestamp("end_time"));
                matches.add(row);
            }
        }
    }
} catch(Exception e) {
    request.setAttribute("error", "Error loading alerts: " + e.getMessage());
}
request.setAttribute("alertsList", alertsList);
request.setAttribute("matches", matches);
%>

<!DOCTYPE html>
<html>
<head>
    <title>My Alerts</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <style>
        body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
        header{background:#1f3c88;color:#fff;padding:22px}
        header h1{margin:0;font-size:24px}
        .container{max-width:960px;margin:28px auto;padding:0 20px}
        .card{background:#fff;border-radius:12px;padding:20px;box-shadow:0 6px 18px rgba(16,24,40,0.08);margin-bottom:18px}
        label{display:block;margin:10px 0 4px;font-weight:600;font-size:14px}
        input{width:100%;padding:10px;border:1px solid #ccd5e0;border-radius:6px;background:#fbfdff;font-size:14px}
        button{padding:12px 20px;border:none;border-radius:8px;background:#1f3c88;color:#fff;font-weight:700;cursor:pointer}
        table{width:100%;border-collapse:collapse;font-size:14px}
        th,td{padding:12px;text-align:left;border-bottom:1px solid #edf0f6}
        th{background:#f0f4ff;text-transform:uppercase;font-size:12px;color:#4b5d7c}
        .flash{padding:12px;border-radius:8px;margin:12px 0}
        .flash.success{background:#e6f7ed;color:#0b6b37}
        .flash.error{background:#fde8e8;color:#a81515}
        .note{font-size:13px;color:#666}
        .back-btn{display:inline-block;margin-top:12px;padding:10px 18px;border-radius:8px;
                  background:#1f3c88;color:#fff;text-decoration:none;font-weight:700}
    </style>
</head>
<body>
<header>
  <h1>🔔 My Alerts</h1>
  <p style="margin:6px 0 0;color:#dfe7ff;font-size:14px">Create alerts to track items and keywords.</p>
</header>
<main class="container">
  <c:if test="${not empty flash}">
    <div class="flash success">${flash}</div>
  </c:if>
  <c:if test="${not empty error}">
    <div class="flash error">${error}</div>
  </c:if>

  <div class="card">
    <h3 style="margin-top:0">Create New Alert</h3>
    <form action="alerts" method="post">
      <label>Keyword</label>
      <input type="text" name="keyword" required placeholder="e.g., laptop, guitar">
      <label>Category (optional)</label>
      <input type="text" name="category" placeholder="Electronics, Music...">
      <button type="submit" style="margin-top:12px">Save Alert</button>
    </form>
  </div>

  <div class="card">
    <h3 style="margin-top:0">Existing Alerts</h3>
    <c:if test="${not empty alertsList}">
      <table>
        <tr><th>ID</th><th>Keyword</th><th>Category</th></tr>
        <c:forEach var="alert" items="${alertsList}">
            <tr>
                <td>${alert.id}</td>
                <td>${alert.keyword}</td>
                <td>${alert.category}</td>
            </tr>
        </c:forEach>
      </table>
    </c:if>
    <c:if test="${empty alertsList}">
      <p class="note">No alerts created yet.</p>
    </c:if>
  </div>

  <div class="card">
    <h3 style="margin-top:0">Matching Active Auctions</h3>
    <c:if test="${not empty matches}">
      <table>
        <tr><th>Auction</th><th>Category</th><th>Current</th><th>Ends</th></tr>
        <c:forEach var="m" items="${matches}">
          <tr>
            <td><a href="auction.jsp?id=${m.id}">${m.name}</a></td>
            <td>${m.category}</td>
            <td>$${m.price}</td>
            <td>${m.endTime}</td>
          </tr>
        </c:forEach>
      </table>
    </c:if>
    <c:if test="${empty matches}">
      <p class="note">No matching auctions right now.</p>
    </c:if>
  </div>

  <a class="back-btn" href="dashboard.jsp">← Back to Dashboard</a>
</main>
</body>
</html>

