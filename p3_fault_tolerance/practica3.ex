################################################
# Fichero:	practica3.ex
# Autor:	755844 - Sergio Garcia Esteban & 758325 - Irene Fumanal Lacoma
# Descrip:	Practica 3 Sistemas distribuidos
# Version:	Final
################################################

#####################################################################
#				FIB
#####################################################################
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

#####################################################################
#				WORKER
#####################################################################
defmodule Worker do
    
	def init do
		Process.sleep(10000)
		worker(&Fib.fibonacci_tr/1, 1, :rand.uniform(10))    
	end
		    
	defp worker(op, service_count, k) do
		[new_op, omission] = if rem(service_count, k) == 0 do
			behavioural_probability = :rand.uniform(100)
			cond do
				behavioural_probability >= 90 -> 
					[&System.halt/1, false]
				behavioural_probability >= 70 -> 
					[&Fib.fibonacci/1, false]
				behavioural_probability >=  50 -> 
					[&Fib.of/1, false]
				behavioural_probability >=  30 -> 
					[&Fib.fibonacci_tr/1, true]
				true	-> 
					[&Fib.fibonacci_tr/1, false]
			end
		else
			[op, false]
		end
		receive do
			{:req, {pid, args}} -> IO.inspect("W-> he recibido tarea voy a resolverla WII");
									resul=op.(args)
									if not omission, do: send(pid, resul)
		end	
		worker(new_op, rem(service_count + 1, k), k)
	end
end

#####################################################################
#				INTER-WORKER: modulo auxiliar
#####################################################################
defmodule InterWorker do
	def iniciar do
			#lanzamos el worker 
		pid_worker=spawn(fn->Worker.init end);
		IO.inspect("IW -> worder lanzado");
		interworker(pid_worker)
	end

	def interworker(pid_worker) do
	
		#Recibe del proxy la tarea y se la manda al worker para que la realice
		#y le devuelva la solucion
		{proxy_pid,t}=receive do
			{:tarea,proxy,num,t} -> IO.inspect("IW -> &&&&&&&&&&&&&&&&&&&&&&&&&&&");
									send(pid_worker,{:req,{self(),num}}); 
									{proxy,t};
			{:comprobacion,pid_pool} -> IO.inspect("IW -> ==============================");
										if (Process.alive?(pid_worker)) do
											Process.exit(pid_worker,:kill);
											pid_wk=spawn(fn->Worker.init end);
											send(pid_pool,{:estoyVivo, pid_wk});
											pid_wk;
										else
											pid_wk=spawn(fn->Worker.init end);
											send(pid_pool,{:estoyVivo, pid_wk});
											pid_wk;
										end
		end
		pid_wk=receive do
			{:comprobacion,pid_pool} -> IO.inspect("IW -> ==============================");
										if (Process.alive?(pid_worker)) do
											Process.exit(pid_worker,:kill);
											pid_wk=spawn(fn->Worker.init end);
											send(pid_pool,{:estoyVivo, pid_wk});
											pid_wk;
										else
											pid_wk=spawn(fn->Worker.init end);
											send(pid_pool,{:estoyVivo, pid_wk});
											pid_wk;
										end
			resultado	->  IO.inspect("IW -> ()()()()()()()()()()()()()()()()");
							send(proxy_pid,{:sol,self(),resultado,t});
							pid_worker;
			

			
		end
		interworker(pid_wk);
	end
end


#####################################################################
#				CLIENTE
#####################################################################
defmodule Cliente do

	def listener() do
		receive do 
			{:result, sol, t_inicial} -> IO.inspect("C OKOKOKOKOKOKOKOKOKOKOKOKOKOKOKOKOKOKOK");
				IO.inspect(Time.diff(Time.utc_now, t_inicial, :millisecond));
		end
		listener()
  	end

  	defp launch(server_pid, ltn_id, 1) do
		t_inicial=Time.utc_now;
		send(server_pid, {ltn_id, t_inicial, 1500})
		IO.inspect("C ++++++++++++++++++@@@@++++++++++++++++++++");
	end

  	defp launch(server_pid, ltn_id, n) when n != 1 do
		t_inicial=Time.utc_now; 
		if rem(n, 3) == 0, 
				do: 	send(server_pid, {ltn_id, t_inicial, :random.uniform(100)}), 
				else: 	send(server_pid, {ltn_id, t_inicial, :random.uniform(36 )})
		IO.inspect("C ++++++++++++++++++++++++++++++++++++++++++");
		launch(server_pid, ltn_id, n - 1)
  	end 
  
  	def genera_workload(server_pid, ltn_id) do
		launch(server_pid,ltn_id, 6 + :random.uniform(2))
		Process.sleep(2000 + :random.uniform(200))
  		genera_workload(server_pid, ltn_id)
 	end

	def iniciar(server_pid) do
		Process.sleep(11000);
		ltn_id=spawn(fn->Cliente.listener() end);
  		genera_workload(server_pid, ltn_id)
 	end

	def iniciar2(server_pid) do
		Process.sleep(11000);
		t=Time.utc_now();
		send(server_pid, {self(), t, 1500});
		IO.inspect("C ++++++++++++++++++++++++++++++++++++++++++");
		receive do 
			{:result, sol, t_inicial} -> IO.inspect("C OKOKOKOKOKOKOKOKOKOKOKOKOKOKOKOKOKOKOK");
							IO.inspect(Time.diff(Time.utc_now, t_inicial, :millisecond));
		end
		iniciar2(server_pid)
 	end

end

#####################################################################
#				INI
#####################################################################
defmodule Init do
    def iniciar do
		Node.connect(:"node0@155.210.154.202")#Cliente
		Node.connect(:"node1@155.210.154.203")#El resto son workers
		Node.connect(:"node2@155.210.154.203")
		Node.connect(:"node3@155.210.154.203")
		Node.connect(:"node4@155.210.154.203")
		Node.connect(:"node1@155.210.154.204")	
		Node.connect(:"node2@155.210.154.204")
		Node.connect(:"node3@155.210.154.204")
		Node.connect(:"node4@155.210.154.204")
		Node.connect(:"node1@155.210.154.205")	
		Node.connect(:"node2@155.210.154.205")
		Node.connect(:"node3@155.210.154.205")
		Node.connect(:"node4@155.210.154.205")
		Node.connect(:"node1@155.210.154.196")	
		Node.connect(:"node2@155.210.154.196")
		Node.connect(:"node3@155.210.154.196")
		Node.connect(:"node4@155.210.154.196")
		Node.connect(:"node1@155.210.154.197")	
		Node.connect(:"node2@155.210.154.197")
		Node.connect(:"node3@155.210.154.197")
		Node.connect(:"node4@155.210.154.197")
		Node.connect(:"node1@155.210.154.199")	
		Node.connect(:"node2@155.210.154.199")
		Node.connect(:"node3@155.210.154.199")
		Node.connect(:"node4@155.210.154.199")
		
        lista_nodos=Node.list;
		me=self();

		pool_pid=spawn(fn->Pool.pool( tl(lista_nodos)) end);	 #Pool

		pid_cliente=Node.spawn(hd(lista_nodos),fn->Cliente.iniciar(me) end); #Cliente ################################OJOOOOOOOO el 2

		Master.master(pool_pid);								 #Master

    end

end

#####################################################################
#				MASTER
#####################################################################
defmodule Master do
    def master(pid_pool) do 
		IO.inspect("M -> MASTER ESTA VIVO");
		#Recibe una peticion de cliente y solicita workers al pool
        {cliente_pid,ini_time,num} = receive do
			{c_pid,time,n} -> 	send(pid_pool,{:dameWK,self()}); 
								{c_pid,time,n};
		end
		IO.inspect("M -> QUIERO WORKERS");
		#Recibe workers del pool y lanza proxy
		receive do
			{:doyWK,list3} ->	IO.inspect("M -> workers recibidos ");
								me=self();
								spawn(fn->Proxy.proxy(me,cliente_pid,pid_pool,num,list3,ini_time) end);
		end
		IO.inspect("M -> TENGO WORKERS");
        master(pid_pool)
    end
end

#####################################################################
#				PROXY
#####################################################################
defmodule Proxy do
	#eliminar el worker con respuesta correcta de la lista
	defp elimino_worker_de_lista(lista,pid) do
		if (lista != []) do
		 	if (pid==hd(lista)) do
				tl(lista);
			else
				list=elimino_worker_de_lista(tl(lista),pid);
				[hd(lista)]++list;
			end
		else
			lista;
		end
	end
	#Enviar fallo al pool cuando se ha cumplido el timeout y no se ha recibido respuesta
	defp envio_error(lista, pid_pool) do
		if (lista != []) do
			send(pid_pool,{:falla,hd(lista)});
			envio_error(tl(lista), pid_pool);
		end
	end

	#Caso 1: no se ha recibido ninguna confirmacion. Si se recibe confirmacion se envia
	#solucion a cliente y ok al pool. Si pasa el timeout y no se ha recibido nada, se manda error
	#al pool con todos los workers que quedan por enviar el resultado.
	defp recibir3(master_pid,num,time,lista,pid_pool,cliente_pid,timeout,tini) when length(lista)==3 do
		receive do
			{:sol,pid_worker,resultado,time} -> 	IO.inspect("PR -> SOLUCION RECIVIDA"); 
													send(cliente_pid,{:result,trunc(resultado),time});
													trunc(resultado);
													send(pid_pool,{:ok,pid_worker}); 
													new_lista=elimino_worker_de_lista(lista,pid_worker);
													t1=Time.utc_now;
													tex=Time.diff(tini,t1, :millisecond);
													#Actualizo timeout
													recibir3(master_pid,num,time,new_lista,pid_pool,cliente_pid,timeout-tex,t1);
		after
			timeout -> 		IO.inspect("PR -> TIMOUT EXCEDIDO1");
							send(hd(lista),{:comprobacion,pid_pool});
							send(hd(tl(lista)),{:comprobacion,pid_pool});
							send(hd(tl(tl(lista))),{:comprobacion,pid_pool});
							send(master_pid,{cliente_pid,time,num});		#3 fallos
							
		end
	end

	#Caso 2: se ha recibido al menos una confirmacion. Si se recibe confirmacion ok al pool. Si pasa el timeout y no se ha recibido nada, se manda error
	#al pool con todos los workers que quedan por enviar el resultado.
	defp recibir3(master_pid,num,time,lista,pid_pool,cliente_pid,timeout,tini) when length(lista) !=0 do
		receive do
			{:sol,pid_worker,resultado,time} ->	IO.inspect("PR -> solucion recivida");
												send(pid_pool,{:ok,pid_worker}); 
												new_lista=elimino_worker_de_lista(lista,pid_worker);
												t1=Time.utc_now;
												tex=Time.diff(tini,t1, :millisecond);
												#Actualizo timeout
												if(new_lista != [])do
													recibir3(master_pid,num,time,new_lista,pid_pool,cliente_pid,timeout-tex,t1);
												end
												
		after
			timeout -> 	IO.inspect("PR -> TIMOUT EXCEDIDO2"); 
						envio_error(lista,pid_pool);		#2 o 1 fallos
						if(length(lista) == 2)do
							send(hd(lista),{:comprobacion,pid_pool});
							send(hd(tl(lista)),{:comprobacion,pid_pool});
						else
							send(hd(lista),{:comprobacion,pid_pool});
						end
		end
	end 

    def proxy(master_pid, cliente_pid,pool_pid,num,list3,time) do 
		elem1=hd(list3)
		elem2=hd(tl(list3))
		elem3=hd(tl(tl(list3)))
		IO.inspect("PR -> START");
		#Envia la tarea a 3 workers
		send(elem1,{:tarea,self(),num,time});
		send(elem2,{:tarea,self(),num,time});
		send(elem3,{:tarea,self(),num,time});
		#Empiezo a medir tiempo para gestionar el timeout
		tini=Time.utc_now;
		#PONER TIMEOUT 
		recibir3(master_pid,num,time,list3,pool_pid,cliente_pid,14000,tini);
		IO.inspect("PR -> FINISHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH");
		#Transcurrrido el timeout, el proxy termina
    end
end


#####################################################################
#				POOL
#####################################################################
defmodule Pool do
    def inicializar_lista([],lista2,l) do
        lista2++[l];
    end
    def inicializar_lista(lista1,lista2,l) do 
        inicializar_lista(tl(lista1), lista2++[l], hd(lista1));
    end


	def loop(nodos_parados, lista_lanzados) when length(lista_lanzados) >= 3 do
		IO.inspect("PO -> ESTOY VIVO");
        {lparados,llanzados}=receive do
            {:dameWK,pid_master} -> elem1= hd(lista_lanzados);l1=tl(lista_lanzados); elem2=hd(l1);l2=tl(l1); elem3=hd(l2);l3=tl(l2);
									send(pid_master, {:doyWK, [elem1,elem2,elem3]});
									IO.inspect(l3);
									{nodos_parados, l3}
			{:estoyVivo,wk_pid}	 -> IO.inspect("PO -> REVIVE0");
									IO.inspect(lista_lanzados++[wk_pid]);
									{nodos_parados, lista_lanzados++[wk_pid]}
			{:ok,wk_pid}		 ->	IO.inspect("PO -> OK0"); 
									IO.inspect(lista_lanzados++[wk_pid]);
									{nodos_parados, lista_lanzados++[wk_pid]}
        end
        loop(lparados,llanzados)
    end
	
	def loop(nodos_parados, lista_lanzados) when length(nodos_parados)+length(lista_lanzados) >= 3 do
		IO.inspect("PO -> ESTOY VIVO");
		{lparados,llanzados}=receive do
			{:dameWK,pid_master} -> cond do
										length(lista_lanzados)==2 ->
											elem1= hd(lista_lanzados);l1=tl(lista_lanzados); elem2=hd(l1);l2=tl(l1); 
											elem3= hd(nodos_parados);l3=tl(nodos_parados);
											#lanzo un worker de los que estaban parados
											pid1=Node.spawn(elem3,fn->InterWorker.iniciar() end);
											#envia los pids de los 3 workers al master
											send(pid_master, {:doyWK, [elem1,elem2,pid1]});
											IO.inspect(l2);
											{l3, l2}
										length(lista_lanzados)==1 ->
											elem1= hd(lista_lanzados);l1=tl(lista_lanzados); 
											elem2=hd(nodos_parados);l2=tl(nodos_parados); elem3= hd(l2);l3=tl(l2);
											#lanza dos workers de los que estaban parados
											pid1=Node.spawn(elem2,fn->InterWorker.iniciar() end);
											pid2=Node.spawn(elem3,fn->InterWorker.iniciar() end);
											#envia los pid de los 3 workers al master
											send(pid_master, {:doyWK, [elem1,pid1,pid2]});
											IO.inspect(l1);
											{l3, l1}
										true ->
											elem1= hd(nodos_parados);l1=tl(nodos_parados); elem2=hd(l1);l2=tl(l1); elem3=hd(l2);l3=tl(l2);
											#lanza los 3 workers
											pid1=Node.spawn(elem1,fn->InterWorker.iniciar end);
											pid2=Node.spawn(elem2,fn->InterWorker.iniciar end);
											pid3=Node.spawn(elem3,fn->InterWorker.iniciar end);
											#envia pid de los 3 workers al master
											send(pid_master, {:doyWK, [pid1,pid2,pid3]});
											IO.inspect(lista_lanzados);
											{l3, lista_lanzados}
									end
			{:estoyVivo,wk_pid}	 -> IO.inspect("PO -> REVIVE1");
									IO.inspect(lista_lanzados++[wk_pid]);
									{nodos_parados, lista_lanzados++[wk_pid]}
			{:ok,wk_pid}		 ->	IO.inspect("PO -> OK1");
									IO.inspect(lista_lanzados++[wk_pid]);
									{nodos_parados, lista_lanzados++[wk_pid]}
        end
        loop(lparados,llanzados)
    end
	def loop(nodos_parados, lista_lanzados) do
		IO.inspect("PO -> ESTOY VIVO");
		{lparados,llanzados}=receive do
			{:estoyVivo,wk_pid}	 -> IO.inspect("PO -> REVIVE2");
									IO.inspect(lista_lanzados++[wk_pid]);
									{nodos_parados, lista_lanzados++[wk_pid]}
            {:ok,wk_pid}		 ->	IO.inspect("PO -> OK2");
									IO.inspect(lista_lanzados++[wk_pid]);
									{nodos_parados, lista_lanzados++[wk_pid]}
        end
        loop(lparados,llanzados)
    end


    def pool(lista_nodos) do
        lista_worker=inicializar_lista(tl(lista_nodos),[],hd(lista_nodos));
		IO.inspect(lista_worker);
        loop(lista_worker,[]);
    end
end






