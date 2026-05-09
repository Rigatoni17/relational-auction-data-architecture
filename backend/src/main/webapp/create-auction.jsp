<%@ page contentType="text/html; charset=UTF-8" %>
<%
Integer userId = (Integer)session.getAttribute("userId");
String role = (String)session.getAttribute("role");
if (userId == null || !"seller".equals(role)) {
    response.sendRedirect("login.jsp");
    return;
}
%>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Create Auction</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333;margin:0}
    .container{max-width:720px;margin:32px auto;padding:0 20px}
    .card{background:#fff;border-radius:12px;padding:22px;box-shadow:0 6px 18px rgba(16,24,40,0.08)}
    h2{margin:0 0 14px;text-align:center;color:#1f3c88}
    label{display:block;margin:10px 0 4px;font-weight:600;font-size:14px}
    input,textarea{width:100%;padding:10px;border:1px solid #ccd5e0;border-radius:6px;background:#fbfdff;font-size:14px}
    textarea{min-height:90px}
    button{width:100%;padding:12px;margin-top:14px;background:#1f3c88;color:#fff;border:none;border-radius:8px;font-size:16px;font-weight:700;cursor:pointer}
    .note{font-size:13px;color:#666;text-align:center;margin-top:10px}
    .back-btn{display:inline-block;margin-top:12px;padding:10px 18px;border-radius:8px;
              background:#1f3c88;color:#fff;text-decoration:none;font-weight:700}
  </style>
</head>
<body>
  <div class="container">
    <div class="card">
      <h2>Create a new auction</h2>
      <form method="post" action="${pageContext.request.contextPath}/seller/create">
        <label>Item name</label>
        <input type="text" name="itemName" required maxlength="120">

        <label>Category</label>
        <input type="text" name="category" maxlength="60" placeholder="Electronics, Music...">

        <label>Description</label>
        <textarea name="description" maxlength="500" placeholder="What makes this item special?"></textarea>

        <label>Start price</label>
        <input type="number" step="0.01" name="startPrice" required>

        <label>Reserve price (optional)</label>
        <input type="number" step="0.01" name="reservePrice">

        <label>End time</label>
        <input type="datetime-local" name="endTime" required>

        <button type="submit">Create Auction</button>
      </form>
      <p class="note"><a class="back-btn" href="dashboard.jsp">← Back to Dashboard</a></p>
    </div>
  </div>
</body>
</html>
