# AUTORES: Rafael Tolosana Calasanz
 # fuentes: 	https://fschuindt.github.io/blog/2017/09/21/concurrent-calculation-of-fibonacci-in-elixir.html
 #			https://blog.rentpathcode.com/clojure-vs-elixir-part-2-fibonacci-code-challenge-13f485f48511
 #			https://alchemist.camp/episodes/fibonacci-tail
 # FICHERO: fibonacci.exs
 # FECHA: 25 de septiembre de 2019
 # TIEMPO: 1 hora
 # DESCRIPCI'ON:  	Compilaci'on de implementaciones de los n'umeros de Fibonacci para los servidores
 #			 	Las opciones de invocaci'on son: Fib.fibonacci(n), Fib.fibonacci_rt(n), Fib.of(n)
 #				M'odulo de operaciones para el cliente (generador de carga de trabajo)
 
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


