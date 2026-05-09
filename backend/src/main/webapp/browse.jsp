<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,java.util.*,java.time.format.DateTimeFormatter,com.buyme.auth.Db,java.math.BigDecimal" %>

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

String categoryFilter = request.getParameter("category");
String sortBy = request.getParameter("sort");
if (sortBy == null || sortBy.isBlank()) sortBy = "endingSoon";

Connection conn = null;
PreparedStatement ps = null;
ResultSet rs = null;
List<Map<String,Object>> auctions = new ArrayList<>();

try {
    conn = Db.get();
    
    StringBuilder sql = new StringBuilder(
        "SELECT a.auction_id, i.name, i.category, i.description, a.current_price, " +
        "a.end_time, s.username AS seller_name, hb.username AS high_bidder " +
        "FROM auctions a JOIN items i ON a.item_id = i.item_id " +
        "JOIN users s ON a.seller_id = s.user_id " +
        "LEFT JOIN users hb ON a.high_bidder_id = hb.user_id " +
        "WHERE a.status = 'active' "
    );
    
    List<Object> params = new ArrayList<>();
    
    if (categoryFilter != null && !categoryFilter.trim().isBlank()) {
        sql.append("AND i.category LIKE ? ");
        params.add("%" + categoryFilter.trim() + "%");
    }
    
    switch (sortBy) {
        case "priceLow": sql.append("ORDER BY a.current_price ASC"); break;
        case "priceHigh": sql.append("ORDER BY a.current_price DESC"); break;
        case "newest": sql.append("ORDER BY a.created_at DESC"); break;
        default: sql.append("ORDER BY a.end_time ASC"); break; // endingSoon
    }
    
    sql.append(" LIMIT 24");
    
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
        row.put("endTime", rs.getTimestamp("end_time"));
        row.put("sellerName", rs.getString("seller_name"));
        row.put("highBidder", rs.getString("high_bidder"));
        auctions.add(row);
    }
    
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Browse Marketplace</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    header{background:#1f3c88;color:#fff;padding:24px}
    header h1{margin:0;font-size:28px}
    .meta{margin-top:8px;font-size:15px;color:#dfe3ff}
    .container{max-width:1200px;margin:28px auto;padding:0 20px}
    .controls{background:#fff;border-radius:10px;padding:20px;margin-bottom:24px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    .control-row{display:flex;gap:20px;align-items:end;flex-wrap:wrap}
    label{font-weight:600;font-size:13px;margin-bottom:6px;display:block}
    input,select{padding:10px;border:1px solid #ccd5e0;border-radius:6px;background:#fbfdff;font-size:14px}
    button{padding:12px 24px;border:none;border-radius:6px;background:#1f3c88;color:#fff;font-size:14px;font-weight:600}
    .marketplace{background:#fff;border-radius:10px;padding:24px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    .marketplace h2{margin-top:0}
    .stats{display:flex;gap:24px;margin-bottom:24px;font-size:14px;color:#666}
    .auction-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:20px}
    .auction-card{background:#fff;border:1px solid #e1e8ff;border-radius:12px;padding:20px;transition:box-shadow 0.2s;box-shadow:0 2px 8px rgba(16,24,40,0.06)}
    .auction-card:hover{box-shadow:0 8px 24px rgba(16,24,40,0.12)}
    .auction-name{font-size:18px;font-weight:600;margin:0 0 8px;line-height:1.3;display:block}
    .auction-meta{font-size:13px;color:#666;margin-bottom:12px;line-height:1.5}
    .auction-price{font-size:20px;font-weight:700;color:#1f3c88;margin:12px 0}
    .auction-footer{display:flex;justify-content:space-between;align-items:center;font-size:13px}
    .badge{padding:4px 10px;border-radius:999px;font-size:11px;text-transform:uppercase;font-weight:600}
    .badge.active{background:#e0f2ff;color:#03539c}
    .time-left{color:#1f3c88;font-weight:600}
    .no-results{padding:60px;text-align:center;color:#666}
    .no-results h3{font-size:22px;margin-bottom:12px}
    @media(max-width:768px){.control-row{flex-direction:column;gap:16px}}
  </style>
</head>
<body>
<header>
  <h1>🛒 Marketplace</h1>
  <div class="meta">
    Browse <%= auctions.size() %> active auctions across all categories
  </div>
</header>

<main class="container">
  <!-- Controls -->
  <div class="controls">
    <form method="get" class="control-row">
      <div style="flex:1;min-width:200px">
        <label>Category</label>
        <input type="text" name="category" value="<%= categoryFilter==null?"":categoryFilter %>" 
               placeholder="All categories">
      </div>
      <div style="display:flex;gap:8px">
        <button type="submit">Filter</button>
        <a href="browse.jsp" style="padding:12px 20px;border:1px solid #ccd5e0;border-radius:6px;
              background:#fff;color:#1f3c88;font-size:14px;font-weight:600;text-decoration:none;
              display:inline-flex;align-items:center;height:48px">Clear</a>
      </div>
    </form>
  </div>

  <!-- Marketplace -->
  <div class="marketplace">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px">
      <h2>Live Auctions</h2>
      <select onchange="location.href='browse.jsp?sort='+this.value+(getParameter('category')?'&category='+getParameter('category'):'')" style="padding:10px;border:1px solid #ccd;border-radius:6px">
        <option value="endingSoon" <%= "endingSoon".equals(sortBy)?"selected":""%>>Ending soonest</option>
        <option value="priceLow" <%= "priceLow".equals(sortBy)?"selected":""%>>Price: Low → High</option>
        <option value="priceHigh" <%= "priceHigh".equals(sortBy)?"selected":""%>>Price: High → Low</option>
        <option value="newest" <%= "newest".equals(sortBy)?"selected":""%>>Newest first</option>
      </select>
    </div>

    <% if (auctions.isEmpty()) { %>
      <div class="no-results">
        <h3>No auctions match your filters</h3>
        <p>Try clearing filters or check back later for new listings.</p>
        <div style="margin-top:24px">
          <a href="dashboard.jsp" style="background:#1f3c88;color:white;padding:12px 24px;
                border-radius:6px;font-weight:600;text-decoration:none">← Back to Dashboard</a>
        </div>
      </div>
    <% } else { %>
      <div class="auction-grid">
        <% for (Map<String,Object> auction : auctions) { %>
        <div class="auction-card">
          <a href="auction.jsp?id=<%= auction.get("auctionId") %>" class="auction-name">
            <%= auction.get("name") %>
          </a>
          <div class="auction-meta">
            <%= auction.get("category") %> • <%= auction.get("sellerName") %>
            <% if (auction.get("highBidder") != null) { %>
              • Leading: <%= auction.get("highBidder") %>
            <% } %>
          </div>
          <div class="auction-price">
            $<%= ((BigDecimal)auction.get("currentPrice")).setScale(2) %>
          </div>
          <div class="auction-footer">
            <span class="badge active">Active</span>
            <span class="time-left">
              <% Timestamp end = (Timestamp)auction.get("endTime"); %>
              <%= java.time.Duration.between(java.time.Instant.now(), end.toInstant())
                  .toHours() %>h <%= java.time.Duration.between(java.time.Instant.now(), end.toInstant())
                  .toMinutesPart() %>m left
            </span>
          </div>
        </div>
        <% } %>
      </div>
    <% } %>
  </div>

  <div style="text-align:center;margin-top:32px;padding:20px 0">
    <a href="dashboard.jsp" style="color:#1f3c88;font-weight:600;font-size:15px;text-decoration:none">
      ← Back to Dashboard
    </a> | 
    <a href="search.jsp" style="color:#1f3c88;font-weight:600;font-size:15px;text-decoration:none">
      🔍 Advanced Search
    </a>
  </div>
</main>

<script>
function getParameter(name) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(name);
}
</script>
</body>
</html>
<%
} catch (Exception e) {
    out.println("<div style='color:red;padding:20px;background:#fee'>Browse failed: " + e.getMessage() + "</div>");
} finally {
    if (rs != null) try { rs.close(); } catch (Exception ignore) {}
    if (ps != null) try { ps.close(); } catch (Exception ignore) {}
    if (conn != null) try { conn.close(); } catch (Exception ignore) {}
}
%>

