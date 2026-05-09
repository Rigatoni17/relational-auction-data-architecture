package com.buyme.auth;
import java.io.InputStream; import java.sql.*; import java.util.Properties;

public class Db {
  static final Properties P = new Properties();
  static {
    try (InputStream in = Db.class.getClassLoader().getResourceAsStream("app.properties")) {
      if (in == null) throw new RuntimeException("app.properties not found on classpath");
      // Ensure MySQL driver registers with DriverManager (defensive)
      Class.forName("com.mysql.cj.jdbc.Driver");
      P.load(in);
      if (P.getProperty("db.url") == null) throw new RuntimeException("Missing property db.url");
    } catch (Exception e) { throw new RuntimeException(e); }
  }
  public static Connection get() throws Exception {
    return DriverManager.getConnection(
      P.getProperty("db.url"),
      P.getProperty("db.user"),
      P.getProperty("db.pass"));
  }
}