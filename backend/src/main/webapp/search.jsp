<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,java.util.*,com.buyme.auth.Db,java.math.BigDecimal" %>

<%
Integer userId = (Integer)session.getAttribute("userId");
if (userId == null) {
    String requested = request.getRequestURI() +
        (request.getQueryString() != null ? "?" + request.getQueryString() : "");
    session = request.getSession(true);
    session.setAttribute("redirectAfterLogin", requested);
    response.sendRedirect("login.jsp");
    return;
}
String role = (String)session.getAttribute("role");

String keyword = request.getParameter("keyword");
String category = request.getParameter("category");
String minPrice = request.getParameter("minPrice");
String maxPrice = request.getParameter("maxPrice");
String sortBy = request.getParameter("sortBy");
if (sortBy == null || sortBy.isBlank()) sortBy = "endTime";

Connection conn = null;
PreparedStatement ps = null;
ResultSet rs = null;
List<Map<String,Object>> results = new ArrayList<>();

try {
    conn = Db.get();

    StringBuilder sql = new StringBuilder(
        "SELECT a.auction_id, i.name, i.category, i.description, a.current_price, " +
        "a.start_price, a.end_time, a.status, u.username AS seller_name, " +
        "hb.username AS high_bidder_name " +
        "FROM auctions a " +
        "JOIN items i ON a.item_id = i.item_id " +
        "JOIN users u ON a.seller_id = u.user_id " +
        "LEFT JOIN users hb ON a.high_bidder_id = hb.user_id " +
        "WHERE a.status = 'active' "
    );
    
    List<Object> params = new ArrayList<>();
    
    if (keyword != null && !keyword.trim().isBlank()) {
        sql.append("AND (i.name LIKE ? OR i.description LIKE ?) ");
        params.add("%" + keyword.trim() + "%");
        params.add("%" + keyword.trim() + "%");
    }
    
    if (category != null && !category.trim().isBlank()) {
        sql.append("AND i.category LIKE ? ");
        params.add("%" + category.trim() + "%");
    }
    
    if (minPrice != null && !minPrice.trim().isBlank()) {
        sql.append("AND a.current_price >= ? ");
        params.add(new BigDecimal(minPrice.trim()));
    }
    
    if (maxPrice != null && !maxPrice.trim().isBlank()) {
        sql.append("AND a.current_price <= ? ");
        params.add(new BigDecimal(maxPrice.trim()));
    }
    
    switch (sortBy) {
        case "priceAsc": sql.append("ORDER BY a.current_price ASC"); break;
        case "priceDesc": sql.append("ORDER BY a.current_price DESC"); break;
        case "name": sql.append("ORDER BY i.name ASC"); break;
        default: sql.append("ORDER BY a.end_time ASC"); break; // endTime
    }
    
    sql.append(" LIMIT 50");
    
    ps = conn.prepareStatement(sql.toString());
    for (int i = 0; i < params.size(); i++) {
        ps.setObject(i + 1, params.get(i));
    }
    
    rs = ps.executeQuery();
    while (rs.next()) {
        Map<String,Object> row = new HashMap<>();
        row.put("auctionId", rs.getInt("auction_id"));
        row.put("name", rs.getString("name"));
        row.put("category", rs.getString("category"));
        row.put("description", rs.getString("description"));
        row.put("currentPrice", rs.getBigDecimal("current_price"));
        row.put("startPrice", rs.getBigDecimal("start_price"));
        row.put("endTime", rs.getTimestamp("end_time"));
        row.put("status", rs.getString("status"));
        row.put("sellerName", rs.getString("seller_name"));
        row.put("highBidderName", rs.getString("high_bidder_name"));
        results.add(row);
    }
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Search Auctions</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    header{background:#1f3c88;color:#fff;padding:20px}
    header h1{margin:0;font-size:24px}
    .meta{margin-top:6px;font-size:14px;color:#dfe3ff}
    .container{max-width:1100px;margin:28px auto;padding:0 20px}
    .search-form{background:#fff;border-radius:10px;padding:20px;margin-bottom:24px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    .form-row{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin-bottom:16px}
    label{display:block;margin-bottom:6px;font-weight:600;font-size:13px}
    input,select{padding:10px;border:1px solid #ccd5e0;border-radius:6px;background:#fbfdff;font-size:14px;width:100%}
    button{padding:12px 24px;border:none;border-radius:6px;background:#1f3c88;color:#fff;font-size:14px;font-weight:600;cursor:pointer}
    .results{background:#fff;border-radius:10px;padding:20px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    .results h3{margin-top:0}
    .result-item{padding:16px;border-bottom:1px solid #edf0f6}
    .result-item:last-child{border-bottom:none}
    .item-name{font-size:18px;font-weight:600;margin:0 0 4px;display:block}
    .item-meta{font-size:13px;color:#666;margin-bottom:8px}
    .price{font-size:16px;font-weight:600;color:#1f3c88}
    .badge{padding:4px 10px;border-radius:999px;font-size:12px;text-transform:uppercase}
    .badge.active{background:#e0f2ff;color:#03539c}
    .no-results{padding:40px;text-align:center;color:#666;font-size:16px}
    .stats{margin-bottom:16px;padding:12px;background:#f0f4ff;border-radius:6px;font-size:14px}
    @media(max-width:768px){.form-row{grid-template-columns:1fr}}
  </style>
</head>
<body>
<header>
  <h1>Search Auctions</h1>
  <div class="meta">
    Find items by keyword, category, or price range
  </div>
</header>

<main class="container">
  <!-- Search form -->
  <div class="search-form">
    <form method="get">
      <div class="form-row">
        <div>
          <label>Keyword</label>
          <input type="text" name="keyword" value="<%= keyword==null ? "" : keyword %>" 
                 placeholder="item name or description">
        </div>
        <div>
          <label>Category</label>
          <input type="text" name="category" value="<%= category==null ? "" : category %>" 
                 placeholder="Electronics, Clothing...">
        </div>
        <div>
          <label>Min Price</label>
          <input type="number" name="minPrice" step="0.01" value="<%= minPrice==null ? "" : minPrice %>"
                 placeholder="$0.00">
        </div>
        <div>
          <label>Max Price</label>
          <input type="number" name="maxPrice" step="0.01" value="<%= maxPrice==null ? "" : maxPrice %>"
                 placeholder="$999.99">
        </div>
      </div>
      <div style="display:flex;gap:12px;justify-content:flex-start">
        <button type="submit">Search Auctions</button>
        <a href="search.jsp" style="padding:12px 24px;border:1px solid #ccd5e0;
              border-radius:6px;background:#fff;color:#1f3c88;font-size:14px;
              text-decoration:none;font-weight:600;display:inline-flex;align-items:center">
          Clear Filters
        </a>
      </div>
    </form>
  </div>

  <!-- Results -->
  <div class="results">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px">
      <h3>Search Results (<%= results.size() %> found)</h3>
      <% if (!results.isEmpty()) { %>
      <select onchange="this.form.submit()" name="sortBy" style="padding:8px;border:1px solid #ccd;border-radius:4px">
        <option value="endTime" <%= "endTime".equals(sortBy)?"selected":""%>>Ending soonest</option>
        <option value="priceAsc" <%= "priceAsc".equals(sortBy)?"selected":""%>>Price: Low to High</option>
        <option value="priceDesc" <%= "priceDesc".equals(sortBy)?"selected":""%>>Price: High to Low</option>
        <option value="name" <%= "name".equals(sortBy)?"selected":""%>>Name A-Z</option>
      </select>
      <% } %>
    </div>
    
    <% if (results.isEmpty()) { %>
      <div class="no-results">
        <p>No auctions match your criteria.</p>
        <p>Try broadening your search or check active auctions on the <a href="dashboard.jsp">dashboard</a>.</p>
      </div>
    <% } else { %>
      <% for (Map<String,Object> auction : results) { %>
      <div class="result-item">
        <a href="auction.jsp?id=<%= auction.get("auctionId") %>" class="item-name">
          <%= auction.get("name") %>
        </a>
        <div class="item-meta">
          <%= auction.get("category") %> • 
          Seller: <%= auction.get("sellerName") %> • 
          <% BigDecimal current = (BigDecimal)auction.get("currentPrice"); %>
          Current: $<%= current.setScale(2) %> 
          <% if (auction.get("highBidderName") != null) { %>
            (Leading: <%= auction.get("highBidderName") %>)
          <% } %>
        </div>
        <div style="margin-top:8px">
          <span class="badge active"><%= auction.get("status") %></span>
          Ends: <%= ((java.sql.Timestamp)auction.get("endTime")).toString().substring(0,16) %>
        </div>
        <% String desc = (String)auction.get("description");
           if (desc != null && !desc.trim().isBlank()) { %>
          <div style="margin-top:8px;font-size:13px;color:#555;line-height:1.4">
            <%= desc.length() > 120 ? desc.substring(0,120) + "..." : desc %>
          </div>
        <% } %>
      </div>
      <% } %>
    <% } %>
  </div>

  <div style="text-align:center;margin-top:24px;padding:16px;background:#fff;border-radius:8px">
    <a href="dashboard.jsp" style="color:#1f3c88;font-weight:600;font-size:15px;text-decoration:none">
      ← Back to Dashboard
    </a>
  </div>
</main>
</body>
</html>
<%
} catch (Exception e) {
    out.println("<div style='color:red;padding:20px;background:#fee'>Search failed: " + e.getMessage() + "</div>");
} finally {
    if (rs != null) try { rs.close(); } catch (Exception ignore) {}
    if (ps != null) try { ps.close(); } catch (Exception ignore) {}
    if (conn != null) try { conn.close(); } catch (Exception ignore) {}
}
%>
