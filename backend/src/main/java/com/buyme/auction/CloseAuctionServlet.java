package com.buyme.auction;

import com.buyme.auth.Db;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.sql.Connection;

@WebServlet(name = "CloseAuctionServlet", urlPatterns = {"/seller/close"})
public class CloseAuctionServlet extends HttpServlet {
  @Override
  protected void doPost(HttpServletRequest req, HttpServletResponse resp)
      throws ServletException, IOException {
    HttpSession session = req.getSession(false);
    if (session == null || session.getAttribute("userId") == null) {
      resp.sendRedirect(req.getContextPath() + "/login.jsp");
      return;
    }
    if (!"seller".equals(session.getAttribute("role"))) {
      session.setAttribute("flashError", "Only sellers can close auctions.");
      resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
      return;
    }
    int auctionId;
    try {
      auctionId = Integer.parseInt(req.getParameter("auctionId"));
    } catch (NumberFormatException e) {
      session.setAttribute("flashError", "Invalid auction.");
      resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
      return;
    }

    try (Connection conn = Db.get()) {
      AuctionService.closeAuction(conn, auctionId, (Integer) session.getAttribute("userId"));
      session.setAttribute("flashSuccess", "Auction closed and winner determined.");
    } catch (IllegalArgumentException ex) {
      session.setAttribute("flashError", ex.getMessage());
    } catch (Exception ex) {
      throw new ServletException(ex);
    }
    resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
  }
}
