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

@WebServlet(name = "AutoBidServlet", urlPatterns = {"/auto-bid"})
public class AutoBidServlet extends HttpServlet {
  @Override
  protected void doPost(HttpServletRequest req, HttpServletResponse resp)
      throws ServletException, IOException {
    HttpSession session = req.getSession(false);
    if (session == null || session.getAttribute("userId") == null) {
      resp.sendRedirect(req.getContextPath() + "/login.jsp");
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

    String maxRaw = req.getParameter("maxAmount");
    String incrementRaw = req.getParameter("increment");
    String redirect = req.getContextPath() + "/auction.jsp?id=" + auctionId;
    if (maxRaw == null || maxRaw.isBlank() || incrementRaw == null || incrementRaw.isBlank()) {
      session.setAttribute("flashError", "Provide both upper limit and increment.");
      resp.sendRedirect(redirect);
      return;
    }

    try (Connection conn = Db.get()) {
      BigDecimal max = new BigDecimal(maxRaw);
      BigDecimal increment = new BigDecimal(incrementRaw);
      AuctionService.registerAutoBid(conn, auctionId,
          (Integer) session.getAttribute("userId"), max, increment);
      session.setAttribute("flashSuccess", "Auto-bid settings saved.");
    } catch (NumberFormatException nf) {
      session.setAttribute("flashError", "Enter valid numeric values.");
    } catch (IllegalArgumentException ex) {
      session.setAttribute("flashError", ex.getMessage());
    } catch (Exception ex) {
      throw new ServletException(ex);
    }
    resp.sendRedirect(redirect);
  }
}
