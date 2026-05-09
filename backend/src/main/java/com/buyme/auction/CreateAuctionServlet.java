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
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;

@WebServlet(name = "CreateAuctionServlet", urlPatterns = {"/seller/create"})
public class CreateAuctionServlet extends HttpServlet {
  @Override
  protected void doPost(HttpServletRequest req, HttpServletResponse resp)
      throws ServletException, IOException {
    HttpSession session = req.getSession(false);
    if (session == null || session.getAttribute("userId") == null) {
      resp.sendRedirect(req.getContextPath() + "/login.jsp");
      return;
    }
    String role = (String) session.getAttribute("role");
    if (!"seller".equals(role)) {
      session.setAttribute("flashError", "Only sellers can create auctions.");
      resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
      return;
    }

    String name = req.getParameter("itemName");
    String description = req.getParameter("description");
    String category = req.getParameter("category");
    String startPriceRaw = req.getParameter("startPrice");
    String reserveRaw = req.getParameter("reservePrice");
    String endTimeRaw = req.getParameter("endTime");

    try (Connection conn = Db.get()) {
      if (startPriceRaw == null || startPriceRaw.isBlank()) {
        throw new IllegalArgumentException("Start price is required.");
      }
      if (endTimeRaw == null || endTimeRaw.isBlank()) {
        throw new IllegalArgumentException("End time is required.");
      }
      BigDecimal startPrice = new BigDecimal(startPriceRaw);
      BigDecimal reservePrice = (reserveRaw == null || reserveRaw.isBlank())
          ? null : new BigDecimal(reserveRaw);
      Timestamp endTime;
      try {
        endTime = Timestamp.valueOf(LocalDateTime.parse(endTimeRaw));
      } catch (DateTimeParseException dt) {
        throw new IllegalArgumentException("End time format is invalid.");
      }
      AuctionService.createAuction(conn, (Integer) session.getAttribute("userId"),
          name, description, category, startPrice, reservePrice, endTime);
      session.setAttribute("flashSuccess", "Auction created successfully.");
    } catch (IllegalArgumentException ex) {
      session.setAttribute("flashError", ex.getMessage());
    } catch (Exception ex) {
      throw new ServletException(ex);
    }
    resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
  }

  @Override
  protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
    // Redirect GET to dashboard to avoid 405
    resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
  }
}
