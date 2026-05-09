package com.buyme.auction;

import com.buyme.auth.Db;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

@WebServlet(name = "AlertsServlet", urlPatterns = {"/alerts"})
public class AlertsServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        HttpSession session = req.getSession(false);
        if (session == null || session.getAttribute("userId") == null) {
            resp.sendRedirect(req.getContextPath() + "/login.jsp");
            return;
        }

        Integer userId = (Integer) session.getAttribute("userId");
        String keyword = req.getParameter("keyword");
        String category = req.getParameter("category");

        try (Connection conn = Db.get();
             PreparedStatement ps = conn.prepareStatement(
                     "INSERT INTO alerts(user_id, keyword, category) VALUES (?, ?, ?)")) {
            ps.setInt(1, userId);
            ps.setString(2, keyword);
            ps.setString(3, category);
            ps.executeUpdate();
            session.setAttribute("flashSuccess", "Alert saved successfully.");
        } catch (Exception e) {
            throw new ServletException(e);
        }

        resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
    }
}
