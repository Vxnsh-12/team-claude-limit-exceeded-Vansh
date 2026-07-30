import React from "react";
import "@/App.css";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { Toaster } from "sonner";
import { AuthProvider, useAuth } from "@/context/AuthContext";
import { AppLayout } from "@/components/AppLayout";
import Login from "@/pages/Login";
import Register from "@/pages/Register";
import Dashboard from "@/pages/Dashboard";
import MapPage from "@/pages/MapPage";
import Leaderboard from "@/pages/Leaderboard";
import Profile from "@/pages/Profile";

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
        element={
          <RequireAuth>
            <AppLayout />
          </RequireAuth>
        }
      >
        <Route path="/" element={<Dashboard />} />
        <Route path="/map" element={<MapPage />} />
        <Route path="/leaderboard" element={<Leaderboard />} />
        <Route path="/profile" element={<Profile />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
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
            position="top-center"
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
