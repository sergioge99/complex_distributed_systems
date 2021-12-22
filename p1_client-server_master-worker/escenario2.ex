################################################
# Fichero:	escenario2.ex
# Autor:	755844 - Sergio Garcia Esteban & 758325 - Irene Fumanal Lacoma
# Descrip:	Escenario 2 - Practica 1 Sistemas distribuidos
# Version:	FinalVersion
################################################

defmodule Ini2 do
    def iniciar do 
        Node.connect(:"master@127.0.0.1");
		IO.inspect(hd(Node.list))
		pid_server=Node.spawn(hd(Node.list),fn->Server.loop() end);
		Cliente.cliente(pid_server,:dos);
    end
end

defmodule Server do
    def loop do 
	IO.puts("S tarea_recibida");
        receive do
            {c_pid,:fib,lista,t} -> spawn(fn->send(c_pid,{:result,Enum.map(lista,fn x -> Fib.fibonacci(x) end),t});IO.puts("Th tarea_ejecutada"); end);
        end
        loop()
    end
end

defmodule Fib do
	def fibonacci(0), do: 0
	def fibonacci(1), do: 1
	def fibonacci(n) when n >= 2 do
		fibonacci(n - 2) + fibonacci(n - 1)
	end
	def fibonacci_tr(n), do: fibonacci_tr(n, 0, 1)
	defp fibonacci_tr(0, _acc1, _acc2), do: 0
	defp fibonacci_tr(1, _acc1, acc2), do: acc2
	defp fibonacci_tr(n, acc1, acc2) do
		fibonacci_tr(n - 1, acc2, acc1 + acc2)
	end

	@golden_n :math.sqrt(5)
  	def of(n) do
 		(x_of(n) - y_of(n)) / @golden_n
	end
 	defp x_of(n) do
		:math.pow((1 + @golden_n) / 2, n)
	end
	def y_of(n) do
		:math.pow((1 - @golden_n) / 2, n)
	end
end	
