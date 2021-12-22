require IEx # Para utilizar IEx.pry

defmodule ServidorGV do
    @moduledoc """
        modulo del servicio de vistas
    """

    # Tipo estructura de datos que guarda el estado del servidor de vistas
    # COMPLETAR  con lo campos necesarios para gestionar
    # el estado del gestor de vistas
    #defstruct vista:{}

    # Constantes
    @latidos_fallidos 4

    @intervalo_latidos 50


    @doc """
        Acceso externo para constante de latidos fallios
    """
    def latidos_fallidos() do
        @latidos_fallidos
    end

    @doc """
        acceso externo para constante intervalo latido
    """
   def intervalo_latidos() do
       @intervalo_latidos
   end

   @doc """
        Generar un estructura de datos vista inicial
    """
    def vista_inicial() do
        %{num_vista: 0, primario: :undefined, copia: :undefined}
    end

    @doc """
        Poner en marcha el servidor para gestión de vistas
        Devolver atomo que referencia al nuevo nodo Elixir
    """
    @spec startNodo(String.t, String.t) :: node
    def startNodo(nombre, maquina) do
                                         # fichero en curso
        NodoRemoto.start(nombre, maquina, __ENV__.file)
    end

    @doc """
        Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
    """
    @spec startService(node) :: boolean
    def startService(nodoElixir) do
        NodoRemoto.esperaNodoOperativo(nodoElixir, __MODULE__)
        
        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoElixir, __MODULE__, :init_sv, [])
   end

    #------------------- FUNCIONES PRIVADAS ----------------------------------

    # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
    def init_sv() do
        Process.register(self(), :servidor_gv)

        spawn(__MODULE__, :init_monitor, [self()]) # otro proceso concurrente

        #### VUESTRO CODIGO DE INICIALIZACION
        bucle_recepcion(:Ini,vista_inicial(),vista_inicial(),false,0,0,0,0,[])
    end

    def init_monitor(pid_principal) do
        send(pid_principal, :procesa_situacion_servidores)
        Process.sleep(@intervalo_latidos)
        init_monitor(pid_principal)
    end


    defp bucle_recepcion(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera) do
		{estado,vV,vT,doyS,latP,latC,retP,retC,lista_espera}=receive do 
			{:latido, n_vista_latido, nodo_emisor} ->
				cond do
					estado==:Ini -> 
						procesar_latido_INI(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,n_vista_latido,nodo_emisor,listaEspera)
					estado==:buscarCopia ->
						procesar_latido_BUSCARCOPIA(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,n_vista_latido,nodo_emisor,listaEspera)
					estado==:esperarConfirmacionPrimario ->
						procesar_latido_ESPERACONFIRMACION(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,n_vista_latido,nodo_emisor,listaEspera)
					estado==:Servicio -> 
						procesar_latido_SERVICIO(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,n_vista_latido,nodo_emisor,listaEspera)
					estado==:fatal -> 
						send({:cliente_gv, nodo_emisor},{:vista_tentativa, vistaTentativa, doyServicio});
						{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera}
				end
        	{:obten_vista_valida, pid} -> 
				procesar_vista(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera,pid)
				
            :procesa_situacion_servidores -> 
				cond do
					estado==:Ini -> 
						{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera}
					estado==:buscarCopia -> 
						procesar_situacion_BUSCARCOPIA(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera)
					estado==:esperarConfirmacionPrimario -> 
						procesar_situacion_ESPERACONFIRMACION(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera)
					estado==:Servicio -> 
						procesar_situacion_SERVICIO(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera)
					estado==:fatal -> 
						{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera}
				end
                
        end
        bucle_recepcion(estado,vV,vT,doyS,latP,latC,retP,retC,lista_espera);
    end
    
    # OTRAS FUNCIONES PRIVADAS VUESTRAS

	defp procesar_vista(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera,pid) do
		send(pid,{:vista_valida, vistaValida, doyServicio});
		{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera};
	end


	defp modVista(vista,n,p,c) do
		vista = %{vista | num_vista: n};
		vista = %{vista | primario: p};
		vista = %{vista | copia: c};
		
		vista;
	end

	defp procesar_latido_INI(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,n_vista_latido,nodo_emisor,listaEspera) do
		if (n_vista_latido==0) do
			newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,nodo_emisor,:undefined)
			#Cambiamos de vista tentativa y de estado.
			send({:cliente_gv, nodo_emisor},{:vista_tentativa, newVista, doyServicio});
			{:buscarCopia,vistaValida,newVista,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera}
		end
	end

	defp procesar_latido_BUSCARCOPIA(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,n_vista_latido,nodo_emisor,listaEspera) do
		if (nodo_emisor==vistaTentativa.primario) do
			#NO SE: ¿Posibilidad de que llegue un latido 0?
			if (n_vista_latido != 0) do
				#Cambiamos de vista tentativa y de estado.
				send({:cliente_gv, nodo_emisor},{:vista_tentativa, vistaTentativa, doyServicio});
				{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario+1,latidoCopia,0,retrasosCopia,listaEspera}
			end
		else	#No es el primario. Será la primera copia
			if (n_vista_latido!=0) do
				#Incrementamos numero vista y añadimos nodo copia
				newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,nodo_emisor)
				send({:cliente_gv, nodo_emisor},{:vista_tentativa, newVista, doyServicio});
				{:esperarConfirmacionPrimario,vistaValida,newVista,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera}
			end
		end
	end

	defp procesar_situacion_BUSCARCOPIA(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera) do
		if (latidoPrimario==0) do
			#¿Puede caerse el primario?
			if (retrasosPrimario != @latidos_fallidos-1) do
				{estado,vistaValida,vistaTentativa,doyServicio,0,latidoCopia,retrasosPrimario+1,retrasosCopia,listaEspera}
			end
		else
			{estado,vistaValida,vistaTentativa,doyServicio,0,latidoCopia,0,retrasosCopia,listaEspera}
		end
	end

	defp procesar_latido_ESPERACONFIRMACION(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,n_vista_latido,nodo_emisor,listaEspera) do	
		if(n_vista_latido==0) do
			cond do
				nodo_emisor==vistaTentativa.primario -> newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,:undefined,:undefined)
													send({:cliente_gv, nodo_emisor},{:vista_tentativa, newVista, doyServicio});
													{:fatal,vistaValida,newVista,doyServicio,0,0,0,0,listaEspera};
				nodo_emisor==vistaTentativa.copia ->if (listaEspera != []) do
														newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,hd(listaEspera))
														send({:cliente_gv, nodo_emisor},{:vista_tentativa, newVista, false});
														{:esperarConfirmacionPrimario,vistaValida,newVista,false,latidoPrimario,0,retrasosPrimario,0,tl(listaEspera)};
													else
														newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,:undefined)
														send({:cliente_gv, nodo_emisor},{:vista_tentativa, newVista, false});
														{:buscarCopia,vistaValida,newVista,false,latidoPrimario,0,retrasosPrimario,0,listaEspera};
													end
				true -> #ni copia ni primario
						newLista=[nodo_emisor]++eliminarNodoDeLista(nodo_emisor,listaEspera,[]);
						send({:cliente_gv, nodo_emisor},{:vista_tentativa,vistaTentativa, false});
						{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,newLista};
			end
		else
			cond do
				nodo_emisor==vistaTentativa.primario -> send({:cliente_gv, nodo_emisor},{:vista_tentativa, vistaTentativa, doyServicio});
														if (n_vista_latido==vistaTentativa.num_vista) do
															{:Servicio,vistaTentativa,vistaTentativa,true,latidoPrimario+1,latidoCopia,0,retrasosCopia,listaEspera};
														else
															{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario+1,latidoCopia,0,retrasosCopia,listaEspera};
														end
				nodo_emisor==vistaTentativa.copia -> send({:cliente_gv, nodo_emisor},{:vista_tentativa, vistaTentativa, doyServicio});
													 {estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia+1,retrasosPrimario,0,listaEspera};
				true -> #ni copia ni primario
						newLista=[nodo_emisor]++eliminarNodoDeLista(nodo_emisor,listaEspera,[]);
						{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,newLista};
			end
		end
	end

	defp procesar_situacion_ESPERACONFIRMACION(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera) do
		if (latidoPrimario==0) do
			if (retrasosPrimario==@latidos_fallidos-1) do ### SE CAE PRIMARIO ###
				newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,:undefined,:undefined)
				{:fatal,vistaValida,newVista,doyServicio,0,0,0,0,listaEspera};
			else
				if (latidoCopia==0) do
					if (retrasosCopia==@latidos_fallidos-1) do ### SE RETRASA PRIMARIO Y SE CAE COPIA ###
						if (listaEspera != []) do
							newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,hd(listaEspera))
							{estado,vistaValida,newVista,doyServicio,0,0,retrasosPrimario+1,0,tl(listaEspera)};
						else
							newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,:undefined)
							{:buscarCopia,vistaValida,newVista,doyServicio,0,0,retrasosPrimario+1,0,tl(listaEspera)};
						end
					else ### SE RETRASA PRIMARIO Y COPIA ###
						{estado,vistaValida,vistaTentativa,doyServicio,0,0,retrasosPrimario+1,retrasosCopia+1,listaEspera};
					end
				else ### SE RETRASA PRIMARIO ###
					{estado,vistaValida,vistaTentativa,doyServicio,0,0,retrasosPrimario+1,0,listaEspera};
				end
			end
		else
			if (latidoCopia==0) do 
				if (retrasosCopia==@latidos_fallidos-1) do ### SE CAE COPIA ###
					if (listaEspera != []) do
						newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,hd(listaEspera))
						{estado,vistaValida,newVista,doyServicio,0,0,0,0,tl(listaEspera)};
					else
						newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,:undefined)
						{:buscarCopia,vistaValida,newVista,doyServicio,0,0,0,0,tl(listaEspera)};
					end
				else ### SE RETRASA COPIA ###
					{estado,vistaValida,vistaTentativa,doyServicio,0,0,0,retrasosCopia+1,listaEspera};
				end
			else ### NO SE RETRASA NI PRIMARIO NI COPIA ###
				{estado,vistaValida,vistaTentativa,doyServicio,0,0,0,0,listaEspera};
			end
		end
	end

	defp procesar_latido_SERVICIO(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,n_vista_latido,nodo_emisor,listaEspera) do	
		if(n_vista_latido==0) do
			cond do
				nodo_emisor==vistaTentativa.primario -> if (listaEspera != []) do ### SE CAE PRIMARIO ###
														newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.copia,hd(listaEspera))
														send({:cliente_gv, nodo_emisor},{:vista_tentativa, newVista, false});
														{:esperarConfirmacionPrimario,vistaValida,newVista,false,latidoCopia,0,retrasosCopia,0,tl(listaEspera)};
													else
														newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.copia,:undefined)
														send({:cliente_gv, nodo_emisor},{:vista_tentativa, newVista, false});
														{:buscarCopia,vistaValida,newVista,false,latidoCopia,0,retrasosCopia,0,listaEspera};
													end
				nodo_emisor==vistaTentativa.copia -> if (listaEspera != []) do ### SE CAE COPIA ###
														newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,hd(listaEspera))
														send({:cliente_gv, nodo_emisor},{:vista_tentativa, newVista, false});
														{:esperarConfirmacionPrimario,vistaValida,newVista,false,latidoPrimario,0,retrasosPrimario,0,tl(listaEspera)};
													else
														newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,:undefined)
														send({:cliente_gv, nodo_emisor},{:vista_tentativa, newVista, false});
														{:buscarCopia,vistaValida,newVista,false,latidoPrimario,0,retrasosPrimario,0,listaEspera};
													end
				true -> #mantenemos al principio de la lista los nodos que han mandado latido más recientemente
						newLista=[nodo_emisor]++eliminarNodoDeLista(nodo_emisor,listaEspera,[]);
						send({:cliente_gv, nodo_emisor},{:vista_tentativa, vistaTentativa, doyServicio});
						{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,newLista};
			end
		else
			cond do 
				nodo_emisor==vistaTentativa.primario -> send({:cliente_gv, nodo_emisor},{:vista_tentativa, vistaTentativa, doyServicio});
														{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario+1,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera};
				nodo_emisor==vistaTentativa.copia -> send({:cliente_gv, nodo_emisor},{:vista_tentativa, vistaTentativa, doyServicio});
													 {estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia+1,retrasosPrimario,retrasosCopia,listaEspera};
				true -> #mantenemos al principio de la lista los nodos que han mandado latido más recientemente
						newLista=[nodo_emisor]++eliminarNodoDeLista(nodo_emisor,listaEspera,[]);
						send({:cliente_gv, nodo_emisor},{:vista_tentativa, vistaTentativa, doyServicio});
						{estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,newLista};
			end
		end
	end

	defp procesar_situacion_SERVICIO(estado,vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia,listaEspera) do
		if (latidoPrimario==0) do
			if (retrasosPrimario==@latidos_fallidos-1) do ### SE CAE PRIMARIO ###
				if (listaEspera != []) do
					newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.copia,hd(listaEspera))
					{:esperarConfirmacionPrimario,vistaValida,newVista,false,0,0,retrasosCopia,0,tl(listaEspera)};
				else
					newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.copia,:undefined)
					{:buscarCopia,vistaValida,newVista,false,0,0,retrasosCopia,0,listaEspera};
				end
			else
				if (latidoCopia==0) do
					if (retrasosCopia==@latidos_fallidos-1) do ### SE RETRASA PRIMARIO Y SE CAE COPIA ###
						if (listaEspera != []) do
							newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,hd(listaEspera))
							{:esperarConfirmacionPrimario,vistaValida,newVista,false,latidoPrimario,0,retrasosPrimario+1,0,tl(listaEspera)};
						else
							newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,:undefined)
							{:buscarCopia,vistaValida,newVista,false,latidoPrimario,0,retrasosPrimario+1,0,listaEspera};
						end
					else ### SE RETRASA PRIMARIO Y COPIA ###
						{estado,vistaValida,vistaTentativa,doyServicio,0,0,retrasosPrimario+1,retrasosCopia+1,listaEspera};
					end
				else ### SE RETRASA PRIMARIO ###
					{estado,vistaValida,vistaTentativa,doyServicio,0,0,retrasosPrimario+1,0,listaEspera};
				end
			end
		else
			if (latidoCopia==0) do 
				if (retrasosCopia==@latidos_fallidos-1) do ### SE CAE COPIA ###
					if (listaEspera != []) do
						newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,hd(listaEspera))
						{:esperarConfirmacionPrimario,vistaValida,newVista,false,0,0,0,0,tl(listaEspera)};
					else
						newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,:undefined)
						{:buscarCopia,vistaValida,newVista,false,0,0,0,0,listaEspera};
					end
				else ### SE RETRASA COPIA ###
					{estado,vistaValida,vistaTentativa,doyServicio,0,0,0,retrasosCopia+1,listaEspera};
				end
			else ### NO SE RETRASA NI PRIMARIO NI COPIA ###
				{estado,vistaValida,vistaTentativa,doyServicio,0,0,0,0,listaEspera};
			end
		end
	end

	defp eliminarNodoDeLista(nodo,lista,lista2) do
		if (lista != []) do
			if(hd(lista)==nodo) do
				eliminarNodoDeLista(nodo,tl(lista),lista2);
			else
				eliminarNodoDeLista(nodo,tl(lista),lista2++hd(lista));
			end
		else
			lista
		end
	end
end
