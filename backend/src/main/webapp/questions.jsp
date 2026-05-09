<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,com.buyme.auth.Db" %>

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

String q = request.getParameter("q");
String auctionFilter = request.getParameter("auctionId");

Connection conn = null;
PreparedStatement ps = null;
ResultSet rs = null;

try {
    conn = Db.get();

    StringBuilder sql = new StringBuilder(
        "SELECT q.question_id, q.auction_id, q.question_text, q.created_at, " +
        "u.username AS asker, a.answer_text, r.username AS rep_name, a.created_at AS answered_at " +
        "FROM questions q " +
        "JOIN users u ON q.user_id = u.user_id " +
        "LEFT JOIN answers a ON a.question_id = q.question_id " +
        "LEFT JOIN users r ON a.rep_id = r.user_id " +
        "WHERE 1=1 "
    );
    if (q != null && !q.isBlank()) {
        sql.append("AND q.question_text LIKE ? ");
    }
    if (auctionFilter != null && !auctionFilter.isBlank()) {
        sql.append("AND q.auction_id = ? ");
    }
    sql.append("ORDER BY q.created_at DESC");

    ps = conn.prepareStatement(sql.toString());

    int idx = 1;
    if (q != null && !q.isBlank()) {
        ps.setString(idx++, "%" + q.trim() + "%");
    }
    if (auctionFilter != null && !auctionFilter.isBlank()) {
        ps.setInt(idx++, Integer.parseInt(auctionFilter));
    }

    rs = ps.executeQuery();
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Questions & Answers</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    .container{max-width:980px;margin:24px auto;padding:0 20px}
    h2{margin-top:0}
    form.inline label{margin-right:10px;font-size:14px}
    input[type=text],input[type=number],textarea{
      padding:8px;border:1px solid #ccd;border-radius:4px;font-size:14px
    }
    button{padding:8px 14px;border:none;border-radius:4px;background:#1f3c88;color:#fff;font-size:14px}
    .card{background:#fff;border-radius:8px;padding:16px;margin-bottom:14px;
          box-shadow:0 4px 12px rgba(16,24,40,0.08)}
    .question{font-weight:600;margin:0 0 4px}
    .meta{font-size:12px;color:#666;margin-bottom:6px}
    .answer{margin-top:6px;padding:8px;border-radius:4px;background:#f0f4ff;font-size:14px}
    .unanswered{color:#b00020;font-size:13px;margin-top:4px}
    .section-title{margin-top:24px;margin-bottom:8px}
    .note{font-size:13px;color:#666}
    .back-btn{display:inline-block;margin-top:12px;padding:10px 18px;border-radius:8px;
              background:#1f3c88;color:#fff;text-decoration:none;font-weight:700}
  </style>
</head>
<body>
<main class="container">
  <h2>Questions & Answers</h2>

  <!-- search/filter -->
  <form class="inline" method="get" action="questions.jsp">
    <label>
      Search text
      <input type="text" name="q" value="<%= q==null?"" : q %>">
    </label>
    <label>
      Auction ID
      <input type="number" name="auctionId" value="<%= auctionFilter==null?"" : auctionFilter %>">
    </label>
    <button type="submit">Search</button>
  </form>

  <!-- ask a new question (buyers/sellers) -->
  <%
    if ("buyer".equals(role) || "seller".equals(role)) {
        String auctionIdForAsk = request.getParameter("forAuction");
  %>
  <h3 class="section-title">Ask a question</h3>
  <form method="post" action="${pageContext.request.contextPath}/questions">
    <label>
      Auction ID
      <input type="number" name="auctionId"
             required value="<%= auctionIdForAsk==null? "" : auctionIdForAsk %>">
    </label>
    <br>
    <label>
      Your question
      <textarea name="question" required rows="3" style="width:100%"></textarea>
    </label>
    <br>
    <button type="submit">Submit question</button>
  </form>
  <p class="note">Customer reps will reply here; check back later for answers.</p>
  <% } %>

  <h3 class="section-title">All questions</h3>
  <%
    boolean any = false;
    while (rs.next()) {
        any = true;
  %>
    <div class="card">
      <p class="question">
        Q#<%= rs.getInt("question_id") %> (Auction <%= rs.getInt("auction_id") %>):
        <%= rs.getString("question_text") %>
      </p>
      <p class="meta">
        Asked by <%= rs.getString("asker") %>
        on <%= rs.getTimestamp("created_at") %>
      </p>
      <%
        String aText = rs.getString("answer_text");
        if (aText != null) {
      %>
        <div class="answer">
          <strong>Answer from <%= rs.getString("rep_name") %>:</strong><br>
          <%= aText %><br>
          <span class="meta">Answered on <%= rs.getTimestamp("answered_at") %></span>
        </div>
      <% } else { %>
        <p class="unanswered">No answer yet.</p>
      <% } %>
    </div>
  <%
    }
    if (!any) {
  %>
    <p class="note">No questions found for this filter.</p>
  <% } %>

  <a class="back-btn" href="dashboard.jsp">&larr; Back to Dashboard</a>
</main>
</body>
</html>
<%
} catch (Exception e) {
    throw new ServletException(e);
} finally {
    if (rs != null) try { rs.close(); } catch (Exception ignore) {}
    if (ps != null) try { ps.close(); } catch (Exception ignore) {}
    if (conn != null) try { conn.close(); } catch (Exception ignore) {}
}
%>
