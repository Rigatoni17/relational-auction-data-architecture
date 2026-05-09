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

@WebServlet("/admin/*")
public class AdminServlet extends HttpServlet {
    
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        // Allow GET requests to pass through to JSPs
        resp.sendRedirect("admin.jsp");
    }
    
    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        String pathInfo = req.getPathInfo();
        
        if ("/create-rep".equals(pathInfo)) {
            HttpSession session = req.getSession();
            
            try (Connection conn = Db.get()) {
                PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO users (username, email, password, role) VALUES (?, ?, ?, 'rep')");
                ps.setString(1, req.getParameter("username"));
                ps.setString(2, req.getParameter("email"));
                ps.setString(3, req.getParameter("password"));
                ps.executeUpdate();
                
                session.setAttribute("flash", "✅ Rep account created successfully!");
            } catch (Exception e) {
                session.setAttribute("flash", "❌ Error: " + e.getMessage());
            }
            resp.sendRedirect("admin.jsp");
        } else {
            resp.sendRedirect("admin.jsp");
        }
    }
}



