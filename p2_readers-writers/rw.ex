################################################
# Fichero:	lector.ex
# Autor:	755844 - Sergio Garcia Esteban & 758325 - Irene Fumanal Lacoma
# Descrip:	Lector - Practica 2 Sistemas distribuidos
# Version:	1.0
################################################

# NOTA: los modulos definidos son: RW y GESTOR

#####################################################################
#				LISTENER
#####################################################################

defmodule Listener do
	#Funcion que representa las reglas de exclusion de las operaciones posibles (read-write)
	def exclude(a,b) do
		if ((a=="write")||(b=="write")) do
			true
		else
			false
		end
	end

	#Recibira los request de otros procesos para solicitar permiso de entrar a la SC
	def listener(main_pid,sem_pid,ecola_pid,op) do
		receive do 
			{:request, nodei, reloji, pidi, opi} -> 
				me=self();
				send(ecola_pid,{:getEstado, me});
				{estado,reloj,maxReloj}=receive do {:estado, estado, reloj, maxReloj} -> {estado,reloj,maxReloj} end;

				#clock=max(maxReloj,reloji)
				if (reloji>maxReloj) do send(ecola_pid,{:maxT,reloji}) end;
				#IO.inspect("-RCV- #{node} recive request con reloj #{reloji}");
				
				# Pide permiso a SEMAFORO para poder realizar la instruccion 11 del algoritmo (debe ejecutarse
				# concurrentemente con la 3 y 4 que pertenecen al modulo MAIN
				send(sem_pid,{:wait,me});
				receive do {:yes} -> end;

				# reloj es el clock de este proceso, y reloji del que pide el request
				# estado==0 significa que estado OUT
				if( (estado>0) && (reloj<reloji || (reloj==reloji && main_pid<pidi)) && exclude(op,opi) ) do
					#Tengo prioridad y añado al otro proceso a la cola de pendientes
					send(ecola_pid,{:encolar, pidi});
					#IO.inspect("<<<<<LISTENER #{node} encola #{nodei}, mi estado #{estado}, mi reloj #{reloj} su reloj #{reloji}, mi op #{op} su op #{opi}");
				else
					#Doy permiso al otro proceso porque tiene prioridad
					send(pidi,{:permision});
					#IO.inspect(">>>>>LISTENER #{node} permission #{nodei}, mi estado #{estado}, mi reloj #{reloj} su reloj #{reloji}, mi op #{op} su op #{opi}");
				end

				#Libera el permiso a SEMAFORO
				send(sem_pid,{:signal});
				
		end
		listener(main_pid,sem_pid,ecola_pid,op);
	end

end


######################################################################################################
#				ECOLA: para gestionar varibles globales como 
#					   estado o la cola de pendientes
######################################################################################################
defmodule Ecola do
	#Funcion para enviar permisos a todos los procesos pertenecientes a la cola de pendientes
	def sendPending(cola) do
		if !(cola==[]) do
			send( hd(cola) , {:permision} );
			sendPending(tl(cola));
		end
	end

	#Gestion de variables "globales"
	def ecola(reloj,maxReloj,estado,cola) do
		{rlj,mxT,est,cl}=receive do
			{:maxT,t} -> {reloj,t,estado,cola};
			#Envia los permisos a todos
			{:out} -> sendPending(cola);{reloj,maxReloj,0,[]};
			{:trying} -> {reloj,maxReloj,1,cola};
			{:in} -> {reloj,maxReloj,2,cola};
			#obtener valores de varibales
			{:getEstado, ltn_pid} -> send( ltn_pid , {:estado, estado, reloj, maxReloj} );
							{reloj,maxReloj,estado,cola};
			{:getT,pid} -> IO.inspect("-CLK- #{node} adquiere reloj #{maxReloj+1}");send( pid , {:T, maxReloj+1} );
					{maxReloj+1,maxReloj+1,estado,cola};
			{:encolar, rw_pid} -> {reloj,maxReloj,estado,cola++[rw_pid]};
		end
		ecola(rlj,mxT,est,cl);
	end

	#iniciar 
	def ecolaIni() do
		ecola(0,0,0,[]);
	end
end


############################################################################################
#				MAIN: quiere realizar operacion (SC)
############################################################################################

defmodule Main do
	#Funcion para pedir permiso de entrada a SC a todos los procesos en la cola ndList
	def sendLoop( ndList, t, op, ltn_pid) do 
		if !(ndList==[]) do
			# Debido al diseño, el propio pid del proceso estara tambien en la lista de nodos
			# por lo tanto lo excluimos
			if (hd(ndList)==ltn_pid) do
				sendLoop( tl(ndList), t, op, ltn_pid);
			else
				me=self();
				send( hd(ndList) , {:request, node, t, me, op} );
				sendLoop( tl(ndList), t, op, ltn_pid);
			end
		end
	end

	#Funcion para confirmar que recibe los permisos de todos los demas procesos
	def receiveLoop(n) do
		receive do {:permision} -> end;
		if !(n==1) do
			receiveLoop(n-1)		
		end
	end

	def begin_op(sem_pid,ndList, op, n, ecola_pid, ltn_pid) do
		me=self();
		#Solicita permiso para realizar en exclusion mutua
		send(sem_pid,	{:wait,me});
		receive do 	{:yes} -> end;
		#Cambia estado 
		send( ecola_pid , {:trying} );
		me=self();
		#Solicita reloj a ECOLA y ademas hace el inremento en 1
		send(ecola_pid,	{:getT,me});
		t=receive do 	{:T,t} -> t end;

		#Sale de exclusion mutua
		send(sem_pid,	{:signal});

		#Solicita permiso a todos los procesos
		sendLoop(ndList, t, op, ltn_pid);
		#Espera a recibir el permiso de todos los demas
		receiveLoop(n-1);
		#Cambia estado a "in"
		send( ecola_pid , {:in} );
	end

	def end_op (ecola_pid) do
		#Cambia el estado y ademas envia a todos los procesos el permiso
		send( ecola_pid , {:out} );
	end

	def read(server_pid, ecola_pid, sem_pid, ltn_pid, pidList, n, op, loop, retardo) do
		
		Process.sleep(retardo);
		#protocolo de entrada SC
		#IO.inspect("..... #{node} LECTOR trying SC");
		begin_op(sem_pid,pidList, "read", n, ecola_pid, ltn_pid);

		#SC
		IO.inspect("+++++ #{node} LECTOR in SC");
		me=self();
		send(server_pid,{op, me});
		leido=receive do {:reply, l} -> l;end;
		#IO.inspect(leido);
		IO.inspect("----- #{node} LECTOR out SC");

		#protocolo de salida SC
		end_op(ecola_pid);
		
		if (loop==1) do
			read(server_pid, ecola_pid, sem_pid, ltn_pid, pidList, n, op, loop, retardo);
		else
			Process.sleep(5000);
			IO.inspect("bye");
		end
	end

	def write(server_pid, ecola_pid, sem_pid, ltn_pid, pidList, n, op, texto, loop, retardo) do

		Process.sleep(retardo);
		#protocolo de entrada SC
		#IO.inspect("..... #{node} ESCRITOR trying SC");
		begin_op(sem_pid,pidList, "write", n, ecola_pid, ltn_pid);

		#SC
		IO.inspect("+++++ #{node} ESCRITOR in SC");
		me=self();
		send(server_pid,{op, me, texto});
		receive do {:reply, :ok} -> end;
		#IO.inspect("Escritura exitosa");
		IO.inspect("----- #{node} ESCRITOR out SC");

		#protocolo de salida SC
		end_op(ecola_pid);
		if (loop==1) do
			write(server_pid, ecola_pid,sem_pid, ltn_pid, pidList, n, op, texto, loop, retardo);
		else
			Process.sleep(5000);
			IO.inspect("bye");
		end
	end
end

#####################################################################
#				SEMAFORO: para gestionar la exclusion mutua
#						  de las instrucciones 1 y 2 con la 11
#####################################################################
defmodule Semaforo do
	def semaforo do
		pid=receive do {:wait,pid} -> pid end;
		send(pid,{:yes});
		receive do {:signal} -> end;
		semaforo();
	end
end



#####################################################################
#				INI
#####################################################################
defmodule Ini do
	def iniLector(gestor_pid, server_pid, n, op, loop, retardo) do
		#Envia al gestor su pid para que lo registre en la lista
		send(gestor_pid,{:pid,self()});
		{pidList,n}=receive do {:lista,pidList,n} -> {pidList,n} end;

		sem_pid=spawn(fn->Semaforo.semaforo() end);
		ecola_pid=spawn(fn->Ecola.ecolaIni() end);
		
		me=self();
		#Lanza la tarea
		main_pid=spawn(fn-> Main.read(server_pid, ecola_pid, sem_pid, me, pidList, n, op, loop, retardo) end);
		Listener.listener(main_pid,sem_pid,ecola_pid,"read");
	end
	def iniEscritor(gestor_pid, server_pid, n, op, texto, loop, retardo) do
		#Envia al gestor su pid para que lo registre en la lista
		send(gestor_pid,{:pid, self()});
		{pidList,n}=receive do {:lista,pidList,n} -> {pidList,n} end;

		sem_pid=spawn(fn->Semaforo.semaforo() end);
		ecola_pid=spawn(fn->Ecola.ecolaIni() end);

		me=self();
		main_pid=spawn(fn-> Main.write(server_pid, ecola_pid, sem_pid, me, pidList, n, op, texto, loop, retardo) end);
		Listener.listener(main_pid,sem_pid,ecola_pid,"write");
	end
end


#####################################################################
#				GESTOR
#####################################################################
defmodule Gestor do
	def sendCola(cortada,cola,restada,n) when restada==1 do
		send(hd(cortada),{:lista, cola, n});
	end
	def sendCola(cortada,cola,restada,n) do
		send(hd(cortada),{:lista, cola, n});
		sendCola(tl(cortada),cola,restada-1, n);
	end

	def encolar(cola,n) when n==1 do
		cola=receive do {:pid,p} -> cola++[p] end;
	end
	def encolar(cola,n) do
		cola=receive do {:pid,p} -> cola++[p] end;
		encolar(cola,n-1);
	end

	def loop do Process.sleep(5000);loop end;


	def escenario1 do
		Node.connect(:"node0@127.0.0.1");#server
		Node.connect(:"node1@127.0.0.1");
		Node.connect(:"node2@127.0.0.1");
		server_pid=Node.spawn(:"node0@127.0.0.1",fn->Repositorio.init() end);
		nRW=2;
		me=self();
		Node.spawn(:"node1@127.0.0.1",fn->Ini.iniEscritor(me, server_pid, nRW, :update_resumen, "Irefu, tú eres el resumen", 0, 0) end);
		Node.spawn(:"node2@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 0, 0) end);
		cola=encolar([],nRW);
		sendCola(cola,cola,nRW,nRW);
		loop;
	end

	def escenario2 do
		Node.connect(:"node0@127.0.0.1");#server
		Node.connect(:"node1@127.0.0.1");
		Node.connect(:"node2@127.0.0.1");
		Node.connect(:"node3@127.0.0.1");
		Node.connect(:"node4@127.0.0.1");
		Node.connect(:"node5@127.0.0.1");
		Node.connect(:"node6@127.0.0.1");
		server_pid=Node.spawn(:"node0@127.0.0.1",fn->Repositorio.init() end);
		nRW=6;
		me=self();
		Node.spawn(:"node1@127.0.0.1",fn->Ini.iniEscritor(me, server_pid, nRW, :update_resumen, "AAAAAAAAAAAA", 1, 0) end);
		Node.spawn(:"node2@127.0.0.1",fn->Ini.iniEscritor(me, server_pid, nRW, :update_resumen, "BBBBBBBBBBBB", 1, 0) end);
		Node.spawn(:"node3@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 1, 0) end);
		Node.spawn(:"node4@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 1, 0) end);
		Node.spawn(:"node5@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 1, 0) end);
		Node.spawn(:"node6@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 1, 0) end);
		cola=encolar([],nRW);
		sendCola(cola,cola,nRW,nRW);
		loop;
	end

	def escenario3 do
		Node.connect(:"node0@127.0.0.1");#server
		Node.connect(:"node1@127.0.0.1");
		Node.connect(:"node2@127.0.0.1");
		Node.connect(:"node3@127.0.0.1");
		Node.connect(:"node4@127.0.0.1");
		server_pid=Node.spawn(:"node0@127.0.0.1",fn->Repositorio.init() end);
		nRW=4;
		me=self();
		Node.spawn(:"node1@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 0, 0) end);
		Node.spawn(:"node2@127.0.0.1",fn->Ini.iniEscritor(me, server_pid, nRW, :update_resumen, "AAAAAAAAAAAA", 0, 5) end);
		Node.spawn(:"node3@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 0, 10) end);
		Node.spawn(:"node4@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 0, 15) end);
		cola=encolar([],nRW);
		sendCola(cola,cola,nRW,nRW);
		loop;
	end
	
	def escenario4 do
		Node.connect(:"node0@127.0.0.1");#server
		Node.connect(:"node1@127.0.0.1");
		Node.connect(:"node2@127.0.0.1");
		Node.connect(:"node3@127.0.0.1");
		Node.connect(:"node4@127.0.0.1");
		Node.connect(:"node5@127.0.0.1");
		Node.connect(:"node6@127.0.0.1");
		server_pid=Node.spawn(:"node0@127.0.0.1",fn->Repositorio.init() end);
		nRW=6;
		me=self();
		Node.spawn(:"node1@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 0, 0) end);
		Node.spawn(:"node2@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 0, 0) end);
		Node.spawn(:"node3@127.0.0.1",fn->Ini.iniEscritor(me, server_pid, nRW, :update_resumen, "AAAAAAAAAAAA", 0, 50) end);
		Node.spawn(:"node4@127.0.0.1",fn->Ini.iniLector(me, server_pid, nRW, :read_resumen, 0, 50) end);
		Node.spawn(:"node5@127.0.0.1",fn->Ini.iniEscritor(me, server_pid, nRW, :update_resumen, "AAAAAAAAAAAA", 0, 100) end);
		Node.spawn(:"node6@127.0.0.1",fn->Ini.iniEscritor(me, server_pid, nRW, :update_resumen, "AAAAAAAAAAAA", 0, 100) end);
		cola=encolar([],nRW);
		sendCola(cola,cola,nRW,nRW);
		loop;
	end
end

