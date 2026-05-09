package com.buyme.auth;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

@WebServlet(name = "RegisterServlet", urlPatterns = {"/register"})
public class RegisterServlet extends HttpServlet {

  @Override
  protected void doPost(HttpServletRequest req, HttpServletResponse resp)
      throws ServletException, IOException {
    req.setCharacterEncoding("UTF-8");
    String username = trim(req.getParameter("username"));
    String email = trim(req.getParameter("email"));
    String password = trim(req.getParameter("password"));
    String confirm = trim(req.getParameter("confirmPassword"));
    String role = trim(req.getParameter("role"));

    if (username == null || password == null || confirm == null
        || username.isEmpty() || password.isEmpty() || role == null) {
      showError("All fields are required.", username, email, role, req, resp);
      return;
    }
    if (!role.equals("buyer") && !role.equals("seller")) {
      showError("Choose either buyer or seller as role.", username, email, role, req, resp);
      return;
    }
    if (!password.equals(confirm)) {
      showError("Passwords do not match.", username, email, role, req, resp);
      return;
    }

    try (Connection conn = Db.get()) {
      if (usernameExists(conn, username)) {
        showError("Username already exists. Pick another one.", username, email, role, req, resp);
        return;
      }
      try (PreparedStatement ps =
               conn.prepareStatement("INSERT INTO users(username,password_hash,email,role) VALUES(?,?,?,?)")) {
        ps.setString(1, username);
        ps.setString(2, password);
        ps.setString(3, email);
        ps.setString(4, role);
        ps.executeUpdate();
      }
    } catch (Exception e) {
      throw new ServletException(e);
    }

    HttpSession session = req.getSession(true);
    session.setAttribute("flash", "Registration successful. You can sign in now.");
    resp.sendRedirect(req.getContextPath() + "/login.jsp");
  }

  @Override
  protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
    resp.sendRedirect(req.getContextPath() + "/register.jsp");
  }

  private static String trim(String value) {
    return value == null ? null : value.trim();
  }

  private static boolean usernameExists(Connection conn, String username) throws Exception {
    try (PreparedStatement ps =
             conn.prepareStatement("SELECT 1 FROM users WHERE username = ?")) {
      ps.setString(1, username);
      try (ResultSet rs = ps.executeQuery()) {
        return rs.next();
      }
    }
  }

  private void showError(String message, String username, String email, String role,
                         HttpServletRequest req, HttpServletResponse resp)
      throws ServletException, IOException {
    req.setAttribute("error", message);
    req.setAttribute("username", username);
    req.setAttribute("email", email);
    req.setAttribute("role", role);
    req.getRequestDispatcher("/register.jsp").forward(req, resp);
  }
}
