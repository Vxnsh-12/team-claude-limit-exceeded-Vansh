import React from "react";
import "@/App.css";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { Toaster } from "sonner";
import { AuthProvider, useAuth } from "@/context/AuthContext";
import { AppLayout } from "@/components/AppLayout";
import Login from "@/pages/Login";
import Register from "@/pages/Register";

const Loading = () => (
  <div className="min-h-screen bg-[#050505] flex items-center justify-center">
    <div className="h-8 w-8 rounded-full border-2 border-[#00E5FF]/30 border-t-[#00E5FF] animate-spin" />
  </div>
);

const RequireAuth = ({ children }) => {
  const { user } = useAuth();
  if (user === undefined) return <Loading />;
  if (!user) return <Navigate to="/login" replace />;
  return children;
};

const RedirectIfAuthed = ({ children }) => {
  const { user } = useAuth();
  if (user === undefined) return <Loading />;
  if (user) return <Navigate to="/" replace />;
  return children;
};

function AppRoutes() {
  return (
    <Routes>
      <Route
        path="/login"
        element={
          <RedirectIfAuthed>
            <Login />
          </RedirectIfAuthed>
        }
      />
      <Route
        path="/register"
        element={
          <RedirectIfAuthed>
            <Register />
          </RedirectIfAuthed>
        }
      />
      <Route
        path="*"
        element={
          <RequireAuth>
            <AppLayout />
          </RequireAuth>
        }
      />
    </Routes>
  );
}

export default function App() {
  return (
    <div className="App">
      <AuthProvider>
        <BrowserRouter>
          <AppRoutes />
          <Toaster
            position="bottom-center"
            offset={100}
            theme="dark"
            toastOptions={{
              style: {
                background: "#0F0F13",
                border: "1px solid rgba(0,229,255,0.35)",
                color: "#fff",
              },
            }}
          />
        </BrowserRouter>
      </AuthProvider>
    </div>
  );
}
