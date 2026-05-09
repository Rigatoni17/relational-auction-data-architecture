package com.buyme.auction;

import com.buyme.auth.Db;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

@WebServlet(name = "QuestionsServlet", urlPatterns = {"/questions"})
public class QuestionsServlet extends HttpServlet {

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
        String questionText = req.getParameter("question");

        int auctionId;
        try {
            auctionId = Integer.parseInt(auctionRaw);
        } catch (NumberFormatException e) {
            session.setAttribute("flashError", "Invalid auction ID.");
            resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
            return;
        }

        if (questionText == null || questionText.isBlank()) {
            session.setAttribute("flashError", "Question cannot be empty.");
            resp.sendRedirect(req.getContextPath() + "/auction.jsp?id=" + auctionId);
            return;
        }

        try (Connection conn = Db.get();
             PreparedStatement ps = conn.prepareStatement(
                     "INSERT INTO questions(auction_id, user_id, question_text) VALUES (?, ?, ?)")) {
            ps.setInt(1, auctionId);
            ps.setInt(2, userId);
            ps.setString(3, questionText);
            ps.executeUpdate();
            session.setAttribute("flashSuccess", "Question submitted successfully.");
        } catch (Exception e) {
            throw new ServletException(e);
        }

        resp.sendRedirect(req.getContextPath() + "/auction.jsp?id=" + auctionId);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
    }
}


// package com.buyme.auction;

// import com.buyme.auth.Db;
// import jakarta.servlet.ServletException;
// import jakarta.servlet.annotation.WebServlet;
// import jakarta.servlet.http.*;
// import java.io.IOException;
// import java.sql.Connection;
// import java.sql.PreparedStatement;

// @WebServlet(name = "QuestionsServlet", urlPatterns = {"/questions"})
// public class QuestionsServlet extends HttpServlet {

//     @Override
//     protected void doPost(HttpServletRequest req, HttpServletResponse resp)
//             throws ServletException, IOException {
//         HttpSession session = req.getSession(false);
//         if (session == null || session.getAttribute("userId") == null) {
//             resp.sendRedirect(req.getContextPath() + "/login.jsp");
//             return;
//         }

//         Integer userId = (Integer) session.getAttribute("userId");
//         String auctionRaw = req.getParameter("auctionId");
//         String questionText = req.getParameter("question");

//         int auctionId;
//         try {
//             auctionId = Integer.parseInt(auctionRaw);
//         } catch (NumberFormatException e) {
//             session.setAttribute("flashError", "Invalid auction.");
//             resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
//             return;
//         }

//         if (questionText == null || questionText.isBlank()) {
//             session.setAttribute("flashError", "Question cannot be empty.");
//             resp.sendRedirect(req.getContextPath() + "/auction.jsp?id=" + auctionId);
//             return;
//         }

//         try (Connection conn = Db.get();
//              PreparedStatement ps = conn.prepareStatement(
//                      "INSERT INTO questions(auction_id, user_id, question_text) VALUES (?, ?, ?)")) {
//             ps.setInt(1, auctionId);
//             ps.setInt(2, userId);
//             ps.setString(3, questionText);
//             ps.executeUpdate();
//             session.setAttribute("flashSuccess", "Question submitted successfully.");
//         } catch (Exception e) {
//             throw new ServletException(e);
//         }

//         resp.sendRedirect(req.getContextPath() + "/auction.jsp?id=" + auctionId);
//     }

//     @Override
//     protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
//         resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
//     }
// }
