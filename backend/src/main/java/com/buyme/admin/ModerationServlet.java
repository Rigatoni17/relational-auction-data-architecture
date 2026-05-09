package com.buyme.admin;

import com.buyme.auth.Db;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

@WebServlet(name = "ModerationServlet", urlPatterns = {"/moderate"})
public class ModerationServlet extends HttpServlet {
  @Override
  protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
    HttpSession session = req.getSession(false);
    if (session == null || session.getAttribute("role") == null) {
      resp.sendRedirect("login.jsp");
      return;
    }
    String role = (String) session.getAttribute("role");
    if (!"rep".equals(role) && !"admin".equals(role)) {
      resp.sendRedirect("dashboard.jsp");
      return;
    }

    String action = req.getParameter("action");
    String idParam = req.getParameter("id");
    if (action == null || idParam == null) {
      resp.sendRedirect("rep-tools.jsp");
      return;
    }

    try (Connection conn = Db.get()) {
      switch (action) {
        case "deleteUser":
          try (PreparedStatement ps = conn.prepareStatement("DELETE FROM users WHERE user_id=?")) {
            ps.setInt(1, Integer.parseInt(idParam));
            ps.executeUpdate();
          }
          session.setAttribute("flash", "User removed.");
          break;
        case "deleteBid":
          try (PreparedStatement ps = conn.prepareStatement("DELETE FROM bids WHERE bid_id=?")) {
            ps.setInt(1, Integer.parseInt(idParam));
            ps.executeUpdate();
          }
          session.setAttribute("flash", "Bid removed.");
          break;
        case "deleteAuction":
          try (PreparedStatement ps = conn.prepareStatement("DELETE FROM auctions WHERE auction_id=?")) {
            ps.setInt(1, Integer.parseInt(idParam));
            ps.executeUpdate();
          }
          session.setAttribute("flash", "Auction removed.");
          break;
        default:
          session.setAttribute("flash", "Unknown action.");
      }
    } catch (Exception e) {
      throw new ServletException(e);
    }

    resp.sendRedirect("rep-tools.jsp");
  }
}
