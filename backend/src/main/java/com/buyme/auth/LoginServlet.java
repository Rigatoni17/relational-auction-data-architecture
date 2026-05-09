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

// LoginServlet.java
@WebServlet(name = "LoginServlet", urlPatterns = {"/login"})
public class LoginServlet extends HttpServlet {

  @Override
  protected void doPost(HttpServletRequest req, HttpServletResponse resp)
      throws ServletException, IOException {

    req.setCharacterEncoding("UTF-8");
    String username = trim(req.getParameter("username"));
    String password = trim(req.getParameter("password"));

    if (username == null || password == null || username.isEmpty() || password.isEmpty()) {
      req.setAttribute("error", "Enter both username and password.");
      req.getRequestDispatcher("/login.jsp").forward(req, resp);
      return;
    }

    try (Connection conn = Db.get();
         PreparedStatement ps = conn.prepareStatement(
             "SELECT user_id, username, role FROM users WHERE username=? AND password_hash=?")) {

      ps.setString(1, username);
      ps.setString(2, password);

      try (ResultSet rs = ps.executeQuery()) {
        if (rs.next()) {
          HttpSession session = req.getSession(true);
          session.setAttribute("userId", rs.getInt("user_id"));
          session.setAttribute("username", rs.getString("username"));
          session.setAttribute("role", rs.getString("role"));

          // check session-stored redirect (e.g., set by search.jsp, questions page, etc.)
          String target = (String) session.getAttribute("redirectAfterLogin");
          if (target != null && !target.isBlank()) {
            session.removeAttribute("redirectAfterLogin");
            resp.sendRedirect(req.getContextPath() + target);
            return;
          }

          // optional: query param ?redirect=/questions.jsp
          String direct = req.getParameter("redirect");
          if (direct != null && !direct.isBlank()) {
            resp.sendRedirect(req.getContextPath() + direct);
          } else {
            resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
          }
        } else {
          req.setAttribute("error", "Invalid credentials.");
          req.getRequestDispatcher("/login.jsp").forward(req, resp);
        }
      }
    } catch (Exception e) {
      throw new ServletException(e);
    }
  }

  @Override
  protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
    resp.sendRedirect(req.getContextPath() + "/login.jsp");
  }

  private static String trim(String value) {
    return value == null ? null : value.trim();
  }
}

