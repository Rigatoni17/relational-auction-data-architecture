package com.buyme.auction;

import com.buyme.auth.Db;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import java.io.IOException;
import java.math.BigDecimal;
import java.sql.Connection;

@WebServlet(name = "PlaceBidServlet", urlPatterns = {"/bid"})
public class PlaceBidServlet extends HttpServlet {
  @Override
  protected void doPost(HttpServletRequest req, HttpServletResponse resp)
      throws ServletException, IOException {
    HttpSession session = req.getSession(false);
    if (session == null || session.getAttribute("userId") == null) {
      resp.sendRedirect(req.getContextPath() + "/login.jsp");
      return;
    }
    Integer userId = (Integer) session.getAttribute("userId");
    String auctionRaw = req.getParameter("auctionId");
    String amountRaw = req.getParameter("amount");

    int auctionId;
    try {
      auctionId = Integer.parseInt(auctionRaw);
    } catch (NumberFormatException e) {
      session.setAttribute("flashError", "Invalid auction.");
      resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
      return;
    }

    String redirect = req.getContextPath() + "/auction.jsp?id=" + auctionId;
    if (amountRaw == null || amountRaw.isBlank()) {
      session.setAttribute("flashError", "Bid amount is required.");
      resp.sendRedirect(redirect);
      return;
    }

    try (Connection conn = Db.get()) {
      BigDecimal amount = new BigDecimal(amountRaw);
      AuctionService.placeManualBid(conn, auctionId, userId, amount);
      session.setAttribute("flashSuccess", "Bid placed successfully.");
    } catch (NumberFormatException nf) {
      session.setAttribute("flashError", "Enter a valid numeric amount.");
    } catch (IllegalArgumentException ex) {
      session.setAttribute("flashError", ex.getMessage());
    } catch (Exception ex) {
      throw new ServletException(ex);
    }
    resp.sendRedirect(redirect);
  }
}
