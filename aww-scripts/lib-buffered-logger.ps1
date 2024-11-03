$definedBufferedLogger = ([System.AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('BufferedLogger', $false, $false) } | Where-Object { $_ -ne $null })
if (-not($definedBufferedLogger)) {
    Add-Type -TypeDefinition @'
    using System;
    using System.Collections.Generic;

    public class BufferedLogger
    {
        private List<Tuple<int, string>> _buffer;
        public const int HOST = 0;
        public const int WARNING = 1;
        public const int ERROR = 2;

        public BufferedLogger()
        {
            _buffer = new List<Tuple<int, string>>();
        }

        public void WriteHost(string message)
        {
            string timestamp = DateTime.Now.ToString("HH:mm:ss.fff");
            _buffer.Add(Tuple.Create(HOST, "[" + timestamp + "] " + message));
        }

        public void WriteError(string message)
        {
            string timestamp = DateTime.Now.ToString("HH:mm:ss.fff");
            _buffer.Add(Tuple.Create(ERROR, "[" + timestamp + "] " + message));
        }

        public void WriteWarning(string message)
        {
            string timestamp = DateTime.Now.ToString("HH:mm:ss.fff");
            _buffer.Add(Tuple.Create(WARNING, "[" + timestamp + "] " + message));
        }

        public void Flush()
        {
            foreach (var entry in _buffer)
            {
                try
                {
                    switch (entry.Item1)
                    {
                        case HOST:
                            Console.ForegroundColor = ConsoleColor.White;
                            Console.BackgroundColor = ConsoleColor.Black;
                            Console.WriteLine(entry.Item2);
                            break;
                        case WARNING:
                            Console.ForegroundColor = ConsoleColor.Yellow;
                            Console.BackgroundColor = ConsoleColor.Black;
                            Console.WriteLine(entry.Item2);
                            break;
                        case ERROR:
                            Console.ForegroundColor = ConsoleColor.Red;
                            Console.BackgroundColor = ConsoleColor.Black;
                            Console.Error.WriteLine(entry.Item2);
                            break;
                        default:
                            Console.ForegroundColor = ConsoleColor.White;
                            Console.BackgroundColor = ConsoleColor.Black;
                            Console.WriteLine(entry.Item2);
                            break;
                    }
                }
                finally
                {
                    Console.ResetColor();
                }
            }
            _buffer.Clear();
        }
    }
'@
}
