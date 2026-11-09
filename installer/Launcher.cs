using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

namespace LaFitness
{
    class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string nodeExe = Path.Combine(baseDir, "runtime", "node.exe");
            string serverJs = Path.Combine(baseDir, "backend", "server.js");
            string flutterExe = Path.Combine(baseDir, "gym_system.exe");

            if (!File.Exists(nodeExe))
            {
                nodeExe = "node"; // fallback to PATH if runtime directory was moved
            }

            Process backendProc = null;
            if (File.Exists(serverJs))
            {
                try
                {
                    ProcessStartInfo psiBackend = new ProcessStartInfo
                    {
                        FileName = nodeExe,
                        Arguments = "\"" + serverJs + "\"",
                        WorkingDirectory = Path.Combine(baseDir, "backend"),
                        CreateNoWindow = true,
                        UseShellExecute = false,
                        WindowStyle = ProcessWindowStyle.Hidden
                    };
                    backendProc = Process.Start(psiBackend);
                    Thread.Sleep(600);
                }
                catch
                {
                    // If backend spawn encounters an error, proceed to launch frontend UI
                }
            }

            try
            {
                if (File.Exists(flutterExe))
                {
                    ProcessStartInfo psiFrontend = new ProcessStartInfo
                    {
                        FileName = flutterExe,
                        WorkingDirectory = baseDir,
                        UseShellExecute = true,
                        WindowStyle = ProcessWindowStyle.Maximized
                    };
                    Process frontendProc = Process.Start(psiFrontend);
                    if (frontendProc != null)
                    {
                        frontendProc.WaitForExit();
                    }
                }
            }
            finally
            {
                if (backendProc != null && !backendProc.HasExited)
                {
                    try
                    {
                        backendProc.Kill();
                    }
                    catch
                    {
                    }
                }
            }
        }
    }
}

