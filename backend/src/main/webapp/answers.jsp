<%@ page contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,com.buyme.auth.Db" %>

<%
Integer userId = (Integer)session.getAttribute("userId");
String role = (String)session.getAttribute("role");
if (userId == null || role == null || !"rep".equals(role)) {
    String requested = request.getRequestURI() +
        (request.getQueryString() != null ? "?" + request.getQueryString() : "");
    session = request.getSession(true);
    session.setAttribute("redirectAfterLogin", requested);
    response.sendRedirect("login.jsp");
    return;
}

String filter = request.getParameter("filter"); // all | unanswered
if (filter == null || filter.isBlank()) filter = "unanswered";

Connection conn = null;
PreparedStatement ps = null;
ResultSet rs = null;

try {
    conn = Db.get();

    String sql =
        "SELECT q.question_id, q.auction_id, q.question_text, q.created_at, " +
        "u.username AS asker, a.answer_text, a.answer_id, a.created_at AS answered_at " +
        "FROM questions q " +
        "JOIN users u ON q.user_id = u.user_id " +
        "LEFT JOIN answers a ON a.question_id = q.question_id ";

    if ("unanswered".equals(filter)) {
        sql += "WHERE a.answer_id IS NULL ";
    }

    sql += "ORDER BY q.created_at DESC";

    ps = conn.prepareStatement(sql);
    rs = ps.executeQuery();
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Rep Q&A Console</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    header{background:#1f3c88;color:#fff;padding:18px}
    header h2{margin:0;font-size:22px}
    header p{margin:4px 0 0;font-size:13px;color:#dfe7ff}
    .container{max-width:980px;margin:20px auto;padding:0 20px}
    .tabs a{margin-right:10px;text-decoration:none;font-size:14px;
            padding:6px 10px;border-radius:999px}
    .tabs .active{background:#1f3c88;color:#fff}
    .tabs .inactive{background:#e0e7ff;color:#1f3c88}
    .card{background:#fff;border-radius:8px;padding:14px 16px;margin:14px 0;
          box-shadow:0 4px 12px rgba(16,24,40,0.08)}
    .q-text{font-weight:600;margin:0 0 4px}
    .meta{font-size:12px;color:#666;margin-bottom:6px}
    .answer-box{margin-top:8px;padding:8px;border-radius:4px;background:#f0f4ff}
    textarea{width:100%;min-height:70px;padding:8px;border:1px solid #ccd;border-radius:4px}
    button{margin-top:6px;padding:8px 14px;border:none;border-radius:4px;
           background:#1f3c88;color:#fff;font-size:14px}
    .note{font-size:13px;color:#666;margin-top:10px}
  </style>
</head>
<body>
<header>
  <h2>Customer Rep – Questions</h2>
  <p>Answer buyer questions and keep auctions clear.</p>
</header>

<main class="container">
  <div class="tabs">
    <a href="answers.jsp?filter=unanswered"
       class="<%= "unanswered".equals(filter) ? "active" : "inactive" %>">
      Unanswered
    </a>
    <a href="answers.jsp?filter=all"
       class="<%= "all".equals(filter) ? "active" : "inactive" %>">
      All questions
    </a>
  </div>

  <%
    String flashSuccess = (String)session.getAttribute("flashSuccess");
    String flashError   = (String)session.getAttribute("flashError");
    if (flashSuccess != null) { session.removeAttribute("flashSuccess"); }
    if (flashError != null) { session.removeAttribute("flashError"); }
  %>
  <% if (flashSuccess != null) { %>
    <p style="color:#00763f;font-weight:600;"><%= flashSuccess %></p>
  <% } %>
  <% if (flashError != null) { %>
    <p style="color:#b00020;font-weight:600;"><%= flashError %></p>
  <% } %>

  <%
    boolean any = false;
    while (rs.next()) {
        any = true;
        String existing = rs.getString("answer_text");
  %>
    <div class="card">
      <p class="q-text">
        Q#<%= rs.getInt("question_id") %> (Auction <%= rs.getInt("auction_id") %>):
        <%= rs.getString("question_text") %>
      </p>
      <p class="meta">
        Asked by <%= rs.getString("asker") %>
        on <%= rs.getTimestamp("created_at") %>
      </p>

      <% if (existing != null && "all".equals(filter)) { %>
        <div class="answer-box">
          <strong>Existing answer:</strong><br>
          <%= existing %><br>
          <span class="meta">Answered on <%= rs.getTimestamp("answered_at") %></span>
        </div>
      <% } %>

      <% if (existing == null) { %>
        <form method="post" action="${pageContext.request.contextPath}/answers">
          <input type="hidden" name="questionId"
                 value="<%= rs.getInt("question_id") %>">
          <label>
            Your answer
            <textarea name="answer" required></textarea>
          </label>
          <button type="submit">Submit answer</button>
        </form>
      <% } %>
    </div>
  <%
    }
    if (!any) {
  %>
    <p class="note">No questions in this view.</p>
  <% } %>

  <p class="note"><a href="dashboard.jsp">&larr; Back to dashboard</a></p>
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
