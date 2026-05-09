<%@ page contentType="text/html; charset=UTF-8" %>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Login</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333}
    .box{max-width:440px;margin:6% auto;padding:30px;background:#fff;border-radius:12px;box-shadow:0 6px 18px rgba(0,0,0,0.08)}
    h2{text-align:center;margin:0 0 18px}
    label{display:block;margin:12px 0 6px;font-size:14px;font-weight:700;color:#333}
    input[type=text],input[type=password]{width:100%;padding:12px;border:1px solid #cdd6e3;background:#fbfdff;border-radius:8px;font-size:15px;box-sizing:border-box}
    button{width:100%;padding:13px;margin-top:14px;background:#2b7cff;color:#fff;border:none;border-radius:8px;font-size:16px;font-weight:700;cursor:pointer}
    .error{color:#b00020;text-align:center;margin-top:12px}
    .success{color:#00763f;text-align:center;margin-top:12px}
    .note{font-size:13px;color:#666;text-align:center;margin-top:10px}
    .note a{color:#2b7cff;text-decoration:none}
  </style>
</head>
<body>
  <div class="box">
    <h2>Sign in to BuyMe Auctions</h2>

    <form method="post" action="${pageContext.request.contextPath}/login">
      <label>Username
        <input type="text" name="username" required autocomplete="username">
      </label>
      <label>Password
        <input type="password" name="password" required autocomplete="current-password">
      </label>
      <button type="submit">Sign in</button>
    </form>

    <%
      String flash = (String)session.getAttribute("flash");
      if(flash!=null) session.removeAttribute("flash");
    %>
    <p class="success"><%= flash==null ? "" : flash %></p>
    <p class="error"><%= request.getAttribute("error")==null?"":request.getAttribute("error") %></p>
    <p class="note">Need an account? <a href="${pageContext.request.contextPath}/register.jsp">Create one here</a>.</p>
    <p class="note">Demo logins: seller_linda / sellerpass, buyer_mia / buyerpass</p>
  </div>
</body>
</html>
