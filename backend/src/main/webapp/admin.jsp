<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,java.util.*,java.math.BigDecimal,com.buyme.auth.Db" %>

<%
Integer userId = (Integer)session.getAttribute("userId");
String role = (String)session.getAttribute("role");

if (userId == null || !"admin".equals(role)) {
    String requested = request.getRequestURI() +
        (request.getQueryString() != null ? "?" + request.getQueryString() : "");
    session = request.getSession(true);
    session.setAttribute("redirectAfterLogin", requested);
    response.sendRedirect("login.jsp");
    return;
}

Connection conn = null;
List<Map<String,Object>> reps = new ArrayList<>();
Map<String,Object> totals = new HashMap<>();
List<Map<String,Object>> topItems = new ArrayList<>();
List<Map<String,Object>> topSellers = new ArrayList<>();
List<Map<String,Object>> topBuyers = new ArrayList<>();
List<Map<String,Object>> byCategory = new ArrayList<>();
List<Map<String,Object>> byBuyer = new ArrayList<>();

try {
    conn = Db.get();
    
    // Total earnings
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT COUNT(*) as total_auctions, " +
        "SUM(CASE WHEN reserve_met THEN closing_price ELSE 0 END) as total_earnings " +
        "FROM auctions WHERE status = 'closed'")) {
        try(ResultSet rs = ps.executeQuery()) {
            if (rs.next()) {
                totals.put("totalAuctions", rs.getLong("total_auctions"));
                totals.put("totalEarnings", rs.getBigDecimal("total_earnings"));
            }
        }
    }
    
    // Reps list
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT user_id, username, email FROM users WHERE role = 'rep' ORDER BY username")) {
        try(ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String,Object> rep = new HashMap<>();
                rep.put("id", rs.getInt("user_id"));
                rep.put("username", rs.getString("username"));
                rep.put("email", rs.getString("email"));
                reps.add(rep);
            }
        }
    }
    
    // Top 5 items by revenue
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT i.name, COUNT(a.auction_id) as sales_count, " +
        "SUM(a.closing_price) as total_revenue " +
        "FROM auctions a JOIN items i ON a.item_id = i.item_id " +
        "WHERE a.status = 'closed' AND a.reserve_met " +
        "GROUP BY i.item_id, i.name ORDER BY total_revenue DESC LIMIT 5")) {
        try(ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String,Object> item = new HashMap<>();
                item.put("name", rs.getString("name"));
                item.put("salesCount", rs.getLong("sales_count"));
                item.put("revenue", rs.getBigDecimal("total_revenue"));
                topItems.add(item);
            }
        }
    }
    
    // Top 5 sellers
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT u.username, COUNT(a.auction_id) as auctions_sold, " +
        "SUM(a.closing_price) as total_revenue " +
        "FROM auctions a JOIN users u ON a.seller_id = u.user_id " +
        "WHERE a.status = 'closed' AND a.reserve_met " +
        "GROUP BY u.user_id, u.username ORDER BY total_revenue DESC LIMIT 5")) {
        try(ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String,Object> seller = new HashMap<>();
                seller.put("username", rs.getString("username"));
                seller.put("auctionsSold", rs.getLong("auctions_sold"));
                seller.put("revenue", rs.getBigDecimal("total_revenue"));
                topSellers.add(seller);
            }
        }
    }
    
    // Top 5 buyers
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT u.username, COUNT(a.auction_id) as items_won, " +
        "SUM(a.closing_price) as total_spent " +
        "FROM auctions a JOIN users u ON a.winner_id = u.user_id " +
        "WHERE a.status = 'closed' AND a.reserve_met " +
        "GROUP BY u.user_id, u.username ORDER BY total_spent DESC LIMIT 5")) {
        try(ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String,Object> buyer = new HashMap<>();
                buyer.put("username", rs.getString("username"));
                buyer.put("itemsWon", rs.getLong("items_won"));
                buyer.put("spent", rs.getBigDecimal("total_spent"));
                topBuyers.add(buyer);
            }
        }
    }

    // Earnings per item type/category
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT i.category, SUM(a.closing_price) AS revenue, COUNT(*) AS sold " +
        "FROM auctions a JOIN items i ON a.item_id=i.item_id " +
        "WHERE a.status='closed' AND a.reserve_met " +
        "GROUP BY i.category ORDER BY revenue DESC")){
      try(ResultSet rs=ps.executeQuery()){
        while(rs.next()){
          Map<String,Object> row=new HashMap<>();
          row.put("category", rs.getString("category"));
          row.put("revenue", rs.getBigDecimal("revenue"));
          row.put("sold", rs.getLong("sold"));
          byCategory.add(row);
        }
      }
    }

    // Earnings per end-user (buyers)
    try(PreparedStatement ps = conn.prepareStatement(
        "SELECT u.username, SUM(a.closing_price) AS spent, COUNT(*) AS won " +
        "FROM auctions a JOIN users u ON a.winner_id=u.user_id " +
        "WHERE a.status='closed' AND a.reserve_met " +
        "GROUP BY u.username ORDER BY spent DESC")){
      try(ResultSet rs=ps.executeQuery()){
        while(rs.next()){
          Map<String,Object> row=new HashMap<>();
          row.put("username", rs.getString("username"));
          row.put("spent", rs.getBigDecimal("spent"));
          row.put("won", rs.getLong("won"));
          byBuyer.add(row);
        }
      }
    }
    
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Admin Dashboard - BuyMe</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    header{background:#1a365d;color:#fff;padding:24px}
    header h1{margin:0;font-size:28px}
    .container{max-width:1200px;margin:28px auto;padding:0 20px}
    .metrics-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:20px;margin-bottom:32px}
    .metric-card{background:#fff;border-radius:12px;padding:24px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    .metric-number{font-size:36px;font-weight:700;color:#1f3c88;margin:8px 0}
    .metric-label{font-size:14px;color:#666;text-transform:uppercase;letter-spacing:0.5px}
    .panel{background:#fff;border-radius:12px;padding:24px;margin-bottom:24px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    .panel h3{margin-top:0;font-size:20px;border-bottom:2px solid #1f3c88;padding-bottom:12px}
    table{width:100%;border-collapse:collapse;font-size:14px}
    th,td{padding:12px 16px;text-align:left;border-bottom:1px solid #edf2f7}
    th{background:#f8faff;color:#374151;font-weight:600;text-transform:uppercase;font-size:12px}
    tr:hover{background:#f8fbff}
    .form-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}
    input,button{padding:12px;border:1px solid #d1d5db;border-radius:8px;font-size:14px}
    input{width:100%;background:#f9fafb}
    button{background:#1f3c88;color:white;border:none;font-weight:600;cursor:pointer}
    button:hover{background:#1e40af}
    .rep-actions{display:flex;gap:8px;align-items:center}
    .flash{padding:16px;border-radius:8px;margin-bottom:20px}
    .flash.success{background:#e6f7ed;color:#0b6b37}
    .flash.error{background:#fde8e8;color:#a81515}
    @media(max-width:768px){.form-grid{grid-template-columns:1fr}}
  </style>
</head>
<body>
<header>
  <h1>🔧 Admin Dashboard</h1>
</header>

<main class="container">
  <% 
    String flash = (String)session.getAttribute("flash");
    if (flash != null) {
        session.removeAttribute("flash");
  %>
    <div class="flash <%= flash.contains("✅") ? "success" : "error" %>"><%= flash %></div>
  <% } %>

  <div class="metrics-grid">
    <div class="metric-card">
      <div class="metric-label">Total Closed Auctions</div>
      <div class="metric-number"><%= totals.get("totalAuctions") != null ? totals.get("totalAuctions") : 0 %></div>
    </div>
    <div class="metric-card">
      <div class="metric-label">Total Platform Earnings</div>
      <div class="metric-number">$<%= totals.get("totalEarnings") != null ? ((BigDecimal)totals.get("totalEarnings")).setScale(2) : "0.00" %></div>
    </div>
    <div class="metric-card">
      <div class="metric-label">Customer Reps</div>
      <div class="metric-number"><%= reps.size() %></div>
    </div>
  </div>

  <!-- Create Rep -->
  <div class="panel">
    <h3>Create Customer Representative</h3>
    <form method="post" action="${pageContext.request.contextPath}/admin/create-rep">
      <div class="form-grid">
        <div>
          <label>Username</label>
          <input type="text" name="username" required maxlength="50">
        </div>
        <div>
          <label>Email</label>
          <input type="email" name="email" required maxlength="120">
        </div>
        <div>
          <label>Password</label>
          <input type="password" name="password" required minlength="4" maxlength="50">
        </div>
        <div style="align-self:end">
          <button type="submit">Create Rep Account</button>
        </div>
      </div>
    </form>
  </div>

  <!-- Current Reps -->
  <div class="panel">
    <h3>Customer Representatives (<%= reps.size() %>)</h3>
    <% if (reps.isEmpty()) { %>
      <p style="color:#666;padding:20px">No customer reps yet. Create one above.</p>
    <% } else { %>
      <table>
        <tr><th>Username</th><th>Email</th><th>Actions</th></tr>
        <% for (Map<String,Object> rep : reps) { %>
        <tr>
          <td><strong><%= rep.get("username") %></strong></td>
          <td><%= rep.get("email") %></td>
          <td class="rep-actions">
            <a href="rep-tools.jsp?repId=<%=rep.get("id")%>" style="color:#1f3c88;font-size:13px">View</a>
            <form method="post" action="${pageContext.request.contextPath}/moderate" style="display:inline">
              <input type="hidden" name="action" value="deleteUser">
              <input type="hidden" name="id" value="<%= rep.get("id") %>">
              <button type="submit" style="background:none;border:none;color:#dc2626;font-size:12px;font-weight:600;cursor:pointer">Delete</button>
            </form>
          </td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>

  <!-- Sales Reports -->
  <div class="panel">
    <h3>🏆 Top Selling Items</h3>
    <% if (topItems.isEmpty()) { %>
      <p>No sales data yet.</p>
    <% } else { %>
      <table>
        <tr><th>Item</th><th>Sold</th><th>Revenue</th></tr>
        <% for (Map<String,Object> item : topItems) { %>
        <tr>
          <td><%= item.get("name") %></td>
          <td><%= item.get("salesCount") %></td>
          <td>$<%= ((BigDecimal)item.get("revenue")).setScale(2) %></td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>

  <div class="panel">
    <h3>💰 Top Sellers</h3>
    <% if (topSellers.isEmpty()) { %>
      <p>No seller data yet.</p>
    <% } else { %>
      <table>
        <tr><th>Seller</th><th>Auctions Sold</th><th>Revenue</th></tr>
        <% for (Map<String,Object> seller : topSellers) { %>
        <tr>
          <td><strong><%= seller.get("username") %></strong></td>
          <td><%= seller.get("auctionsSold") %></td>
          <td>$<%= ((BigDecimal)seller.get("revenue")).setScale(2) %></td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>

  <div class="panel">
    <h3>👑 Top Buyers</h3>
    <% if (topBuyers.isEmpty()) { %>
      <p>No buyer data yet.</p>
    <% } else { %>
      <table>
        <tr><th>Buyer</th><th>Items Won</th><th>Total Spent</th></tr>
        <% for (Map<String,Object> buyer : topBuyers) { %>
        <tr>
          <td><strong><%= buyer.get("username") %></strong></td>
          <td><%= buyer.get("itemsWon") %></td>
          <td>$<%= ((BigDecimal)buyer.get("spent")).setScale(2) %></td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>

  <div class="panel">
    <h3>📂 Earnings by Category</h3>
    <% if (byCategory.isEmpty()) { %>
      <p>No category data yet.</p>
    <% } else { %>
      <table>
        <tr><th>Category</th><th>Sold</th><th>Revenue</th></tr>
        <% for (Map<String,Object> cat : byCategory) { %>
        <tr>
          <td><%= cat.get("category")==null ? "(uncategorized)" : cat.get("category") %></td>
          <td><%= cat.get("sold") %></td>
          <td>$<%= ((BigDecimal)cat.get("revenue")).setScale(2) %></td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>

  <div class="panel">
    <h3>🧾 Buyer Spend (all end-users)</h3>
    <% if (byBuyer.isEmpty()) { %>
      <p>No buyer spending data yet.</p>
    <% } else { %>
      <table>
        <tr><th>Buyer</th><th>Items Won</th><th>Total Spent</th></tr>
        <% for (Map<String,Object> buyer : byBuyer) { %>
        <tr>
          <td><strong><%= buyer.get("username") %></strong></td>
          <td><%= buyer.get("won") %></td>
          <td>$<%= ((BigDecimal)buyer.get("spent")).setScale(2) %></td>
        </tr>
        <% } %>
      </table>
    <% } %>
  </div>

  <div style="text-align:center;margin-top:32px">
    <a href="dashboard.jsp" style="color:#1f3c88;font-weight:600;font-size:16px;text-decoration:none">
      ← Back to Dashboard
    </a>
  </div>
</main>
</body>
</html>
<%
} catch (Exception e) {
    out.println("<div style='color:red;padding:20px;background:#fee'>Admin error: " + e.getMessage() + "</div>");
} finally {
    if (conn != null) try { conn.close(); } catch (Exception ignore) {}
}
%>
