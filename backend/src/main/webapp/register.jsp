<%@ page contentType="text/html; charset=UTF-8" %>
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Create Account</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;background:#f4f7fb;color:#333}
    .box{max-width:420px;margin:6% auto;padding:24px;background:#fff;border-radius:8px;box-shadow:0 6px 18px rgba(0,0,0,0.06)}
    h2{text-align:center;margin:0 0 16px}
    label{display:block;margin:8px 0;font-size:14px}
    input[type=text],input[type=password]{width:100%;padding:10px;border:1px solid #ccd;background:#fbfdff;border-radius:4px}
    button{width:100%;padding:10px;margin-top:12px;background:#2b7cff;color:#fff;border:none;border-radius:4px;font-size:16px}
    .error{color:#b00020;text-align:center;margin-top:12px}
    .note{font-size:13px;color:#666;text-align:center;margin-top:10px}
    .note a{color:#2b7cff;text-decoration:none}
  </style>
</head>
<body>
  <div class="box">
    <h2>Create your account</h2>
<%
  String username = (String)request.getAttribute("username");
  if(username==null) username="";
  String email = (String)request.getAttribute("email");
  if(email==null) email="";
  String roleValue = (String)request.getAttribute("role");
  if(roleValue==null) roleValue="buyer";
%>
    <form method="post" action="${pageContext.request.contextPath}/register">
      <label>Username
        <input type="text" name="username" required maxlength="50" value="<%= username %>">
      </label>
      <label>Email
        <input type="text" name="email" required maxlength="120" value="<%= email %>">
      </label>
      <label>Password
        <input type="password" name="password" required minlength="4" maxlength="50">
      </label>
      <label>Confirm password
        <input type="password" name="confirmPassword" required minlength="4" maxlength="50">
      </label>
      <label>Role
        <select name="role" required>
          <option value="buyer" <%= "buyer".equals(roleValue)?"selected":"" %>>Buyer</option>
          <option value="seller" <%= "seller".equals(roleValue)?"selected":"" %>>Seller</option>
        </select>
      </label>
      <button type="submit">Register</button>
    </form>
    <p class="error"><%= request.getAttribute("error")==null?"":request.getAttribute("error") %></p>
    <p class="note">Already registered? <a href="${pageContext.request.contextPath}/login.jsp">Sign in instead</a>.</p>
  </div>
</body>
</html>
