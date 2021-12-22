################################################
# Fichero:	escenario3.ex
# Autor:	755844 - Sergio Garcia Esteban & 758325 - Irene Fumanal Lacoma
# Descrip:	Escenario 3 - Practica 1 Sistemas distribuidos
# Version:	FinalVersion
################################################

defmodule Ini3 do
    def iniciar do
		Node.connect(:"master@127.0.0.1")
		#Node.connect(:"node@155.210.154.191")
		#Node.connect(:"node@155.210.154.194")
		#Node.connect(:"node@155.210.154.195")
		#Node.connect(:"node@155.210.154.196")
		#Node.connect(:"node@155.210.154.197")
		#Node.connect(:"node@155.210.154.201")
		#Node.connect(:"node@155.210.154.202")
		#Node.connect(:"node@155.210.154.203")
		#Node.connect(:"node@155.210.154.204")
		#Node.connect(:"node@155.210.154.205")
		#Node.connect(:"node@155.210.154.208")
		#Node.connect(:"node@155.210.154.210")
		
        lista_nodos=Node.list;
	IO.inspect(tl(lista_nodos));
        pid_pool=Node.spawn(hd(lista_nodos),fn->Pool.pool(tl(lista_nodos)) end);
        pid_master=Node.spawn(hd(lista_nodos),fn->Master.master(pid_pool) end);
        IO.inspect("Todo preparado");
        Cliente.cliente(pid_master,:tres);
    end
end

defmodule Master do
    def master(pid_pool) do 
		#IO.puts("M procesando");
        {lista,op,c_pid,t}=receive do
            {cliente_pid,op2,lista2,t2} -> send(pid_pool,{:worker,self()});
                                         {lista2,op2,cliente_pid,t2};
        end
        #IO.puts("M pid_worker_recibido");
        receive do
            {:worker,pid_worker} -> send(pid_worker,{c_pid,op,lista,pid_pool,t});
        end
        IO.puts("M tarea_enviada_a_worker");
        master(pid_pool)
    end
end

defmodule Pool do
    def inicializar_lista([],lista2,l) do
        lista2++[l,l,l,l];
    end
    def inicializar_lista(lista1,lista2,l) do 
        inicializar_lista(tl(lista1),lista2++[l,l,l,l],hd(lista1));
    end
	def loop(lista_worker) when lista_worker != [] do
        lista=receive do
            {:worker,pid_master} -> pid_worker= Node.spawn(hd(lista_worker),fn-> Worker.work end); 
                                    send(pid_master,{:worker,pid_worker}); 
                                    #IO.puts("P worker_creado_y_entregado #{hd(lista_worker)}");
                                    tl(lista_worker);
            {:worker_end,nodo} -> IO.puts("P worker_añadido_a_pool #{nodo}"); 
                                  [nodo]++lista_worker; 
        end
		IO.inspect(lista_worker);
		
        loop(lista)
    end
	def loop(lista_worker) do
		lista=receive do
			{:worker_end,nodo} -> IO.puts("P worker_añadido_a_pool_VACIO #{nodo}"); 
                                  [nodo]++lista_worker; 
			end
	#IO.inspect(lista_worker);
	loop(lista)
	end
    
    def pool(lista_nodos) do
		#IO.puts("P iniciando");
        lista_worker=inicializar_lista(tl(lista_nodos),[node,node],hd(lista_nodos));
        loop(lista_worker);
    end
end

defmodule Worker do
    def work do
		#IO.puts("W worker #{node} esperando")
        receive do
            {c_pid,:fib,lista,pid_pool,t} -> send(c_pid,{:result,Enum.map(lista,fn x -> Fib.fibonacci(x) end),t});
                                             send(pid_pool,{:worker_end,node});IO.puts("W resultado enviado #{node}");
            {c_pid,:fib_tr,lista,pid_pool,t} -> send(c_pid,{:result,Enum.map(lista,fn x -> Fib.fibonacci_tr(x) end),t});
                                          send(pid_pool,{:worker_end,node});
        end
        
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
