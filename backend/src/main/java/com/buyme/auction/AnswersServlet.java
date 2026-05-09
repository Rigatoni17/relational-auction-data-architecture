package com.buyme.auction;

import com.buyme.auth.Db;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

@WebServlet(name = "AnswersServlet", urlPatterns = {"/answers"})
public class AnswersServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        HttpSession session = req.getSession(false);
        if (session == null || session.getAttribute("userId") == null) {
            resp.sendRedirect(req.getContextPath() + "/login.jsp");
            return;
        }

        String role = (String) session.getAttribute("role");
        if (!"rep".equals(role)) {
            session.setAttribute("flashError", "Only reps can submit answers.");
            resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
            return;
        }

        Integer repId = (Integer) session.getAttribute("userId");
        String questionRaw = req.getParameter("questionId");
        String answerText = req.getParameter("answer");

        int questionId;
        try {
            questionId = Integer.parseInt(questionRaw);
        } catch (NumberFormatException e) {
            session.setAttribute("flashError", "Invalid question.");
            resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
            return;
        }

        if (answerText == null || answerText.isBlank()) {
            session.setAttribute("flashError", "Answer cannot be empty.");
            resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
            return;
        }

        try (Connection conn = Db.get();
             PreparedStatement ps = conn.prepareStatement(
                     "INSERT INTO answers(question_id, rep_id, answer_text) VALUES (?, ?, ?)")) {
            ps.setInt(1, questionId);
            ps.setInt(2, repId);
            ps.setString(3, answerText);
            ps.executeUpdate();
            session.setAttribute("flashSuccess", "Answer submitted successfully.");
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


// package com.buyme.auction;

// import com.buyme.auth.Db;
// import jakarta.servlet.ServletException;
// import jakarta.servlet.annotation.WebServlet;
// import jakarta.servlet.http.*;
// import java.io.IOException;
// import java.sql.Connection;
// import java.sql.PreparedStatement;

// @WebServlet(name = "AnswersServlet", urlPatterns = {"/answers"})
// public class AnswersServlet extends HttpServlet {

//     @Override
//     protected void doPost(HttpServletRequest req, HttpServletResponse resp)
//             throws ServletException, IOException {
//         HttpSession session = req.getSession(false);
//         if (session == null || session.getAttribute("userId") == null) {
//             resp.sendRedirect(req.getContextPath() + "/login.jsp");
//             return;
//         }

//         String role = (String) session.getAttribute("role");
//         if (!"rep".equals(role)) {
//             session.setAttribute("flashError", "Only reps can answer questions.");
//             resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
//             return;
//         }

//         Integer repId = (Integer) session.getAttribute("userId");
//         String questionRaw = req.getParameter("questionId");
//         String answerText = req.getParameter("answer");

//         int questionId;
//         try {
//             questionId = Integer.parseInt(questionRaw);
//         } catch (NumberFormatException e) {
//             session.setAttribute("flashError", "Invalid question.");
//             resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
//             return;
//         }

//         if (answerText == null || answerText.isBlank()) {
//             session.setAttribute("flashError", "Answer cannot be empty.");
//             resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
//             return;
//         }

//         try (Connection conn = Db.get();
//              PreparedStatement ps = conn.prepareStatement(
//                      "INSERT INTO answers(question_id, rep_id, answer_text) VALUES (?, ?, ?)")) {
//             ps.setInt(1, questionId);
//             ps.setInt(2, repId);
//             ps.setString(3, answerText);
//             ps.executeUpdate();
//             session.setAttribute("flashSuccess", "Answer submitted successfully.");
//         } catch (Exception e) {
//             throw new ServletException(e);
//         }

//         resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
//     }

//     @Override
//     protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
//         resp.sendRedirect(req.getContextPath() + "/dashboard.jsp");
//     }
// }
