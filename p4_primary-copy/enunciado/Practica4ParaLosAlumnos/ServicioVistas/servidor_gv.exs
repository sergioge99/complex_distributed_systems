require IEx # Para utilizar IEx.pry

defmodule ServidorGV do
    @moduledoc """
        modulo del servicio de vistas
    """

    # Tipo estructura de datos que guarda el estado del servidor de vistas
    # COMPLETAR  con lo campos necesarios para gestionar
    # el estado del gestor de vistas
    defstruct [num_vista: 0, primario: :undefined, copia: :undefined]

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

		vistaValida = %ServidorGV{}
		vistaTentativa = vistaValida
        bucle_recepcion(vistaValida,vistaTentativa,0,0,0,0,0)
    end

    def init_monitor(pid_principal) do
        send(pid_principal, :procesa_situacion_servidores)
        Process.sleep(@intervalo_latidos)
        init_monitor(pid_principal)
    end


    defp bucle_recepcion(vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia) do

        {vV,vT,dS,lP,lC,rP,rC} = receive do
        	{:latido, n_vista_latido, nodo_emisor} ->

				if(n_vista_latido==0) do ### COMPROBAMOS SI SE HA CAIDO UN NODO ###
					if(nodo_emisor==vistaTentativa.primario) do
						if(doyServicio==0) do ### cae primario y perdemos los datos ###
							IO.inspect("HEMOS PERDIDO LOS DATOS");
						else ### cae primario, copia pasa a primario, buscamos copia y dejamos de dar servicio ###
							newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.copia,:undefined);
							{vistaValida,newVista,0,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia}
						end
					end
					if(nodo_emisor==vistaTentativa.copia) do ### cae copia, dejamos de dar servicio, buscamos copia ###
						newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,:undefined);
						{vistaValida,newVista,0,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia}
					end
				end
		        if (vistaTentativa.primario==:undefined) do ### BUSCANDO PRIMARIO ### (al principio)
					newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,nodo_emisor,:undefined);
					send(nodo_emisor,{:vista_tentativa, newVista, doyServicio});
					{vistaValida,newVista,doyServicio,latidoPrimario+1,latidoCopia,retrasosPrimario,retrasosCopia}

				else
					if(doyServicio==0) do
						if(vistaTentativa.copia==:undefined) do ### BUSCANDO COPIA ###
							if(nodo_emisor==vistaTentativa.primario) do #ack latido primario
								send(nodo_emisor,{:vista_tentativa, vistaTentativa, doyServicio});
								{vistaValida,vistaTentativa,doyServicio,latidoPrimario+1,latidoCopia,retrasosPrimario,retrasosCopia}
							else	#el emisor del latido será la nueva copia
								newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,nodo_emisor);
								send(nodo_emisor,{:vista_tentativa, newVista, doyServicio});
								{vistaValida,newVista,doyServicio,latidoPrimario,latidoCopia+1,retrasosPrimario,retrasosCopia}
							end

						else	### ESPERANDO CONFIRMACION PRIMARIO ###
							if(nodo_emisor != vistaTentativa.primario) do # si el latido no es del primario respondemos ack
								if(nodo_emisor==vistaTentativa.copia) do # si es la copia registramos su latido (+1)
									send(nodo_emisor,{:vista_tentativa, vistaTentativa, doyServicio});
									{vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia+1,retrasosPrimario,retrasosCopia}
								else	#si es nodo en espera respondemos ack
									send(nodo_emisor,{:vista_tentativa, vistaTentativa, doyServicio});
									{vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia}
								end
							else	#latido primario
								if(n_vista_latido != vistaTentativa.num_vista) do #si no conoce la nueva vista se la mandamos
									send(nodo_emisor,{:vista_tentativa, vistaTentativa, doyServicio});
									{vistaValida,vistaTentativa,doyServicio,latidoPrimario+1,latidoCopia,retrasosPrimario,retrasosCopia}
								else #si confirma la vista ya podemos atender a los clientes
									send(nodo_emisor,{:vista_tentativa, vistaTentativa, doyServicio});
									{vistaTentativa,vistaTentativa,1,latidoPrimario+1,latidoCopia,retrasosPrimario,retrasosCopia}
								end
							end
						end

					else ### ESTAMOS DANDO SERVICIO A CLIENTES ###
						if(nodo_emisor==vistaValida.primario) do
							send(nodo_emisor,{:vista_tentativa, vistaValida, doyServicio});
							{vistaValida,vistaTentativa,doyServicio,latidoPrimario+1,latidoCopia,retrasosPrimario,retrasosCopia}
						else
							if(nodo_emisor==vistaValida.copia) do
								send(nodo_emisor,{:vista_tentativa, vistaValida, doyServicio});
								{vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia+1,retrasosPrimario,retrasosCopia}
							else
								send(nodo_emisor,{:vista_tentativa, vistaValida, doyServicio});
								{vistaValida,vistaTentativa,doyServicio,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia}
							end
						end
					end

				end
                



        	{:obten_vista_valida, pid} ->
				send(pid,{:vista_valida, vistaValida, doyServicio});


            :procesa_situacion_servidores ->
                if(vistaValida.primario != :undefined) do
					if(latidoPrimario==0) do
						if(retrasosPrimario==@latidos_fallidos-1) do ### CAE PRIMARIO ###
							if(doyServicio==0) do ## perdemos los datos ##
								IO.inspect("HEMOS PERDIDO LOS DATOS");
							else ## cae primario, copia pasa a primario, buscamos copia y dejamos de dar servicio ##
								newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.copia,:undefined);
								{vistaValida,newVista,0,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia}
							end
						else	### PRIMARIO SE RETRASA ###
							{vistaValida,vistaTentativa,doyServicio,0,0,retrasosPrimario+1,retrasosCopia}
						end
					end
				end
				if(vistaValida.copia != :undefined) do
					if(latidoCopia==0) do
						if(retrasosCopia==@latidos_fallidos-1) do ### CAE COPIA ###
							newVista=modVista(vistaTentativa,vistaTentativa.num_vista+1,vistaTentativa.primario,:undefined);
							{vistaValida,newVista,0,latidoPrimario,latidoCopia,retrasosPrimario,retrasosCopia}
						else	### COPIA SE RETRASA ###
							{vistaValida,vistaTentativa,doyServicio,0,0,retrasosPrimario+1,retrasosCopia}
						end
					end
				end

        end

        bucle_recepcion(vV,vT,dS,lP,lC,rP,rC)
    end
    
    # OTRAS FUNCIONES PRIVADAS VUESTRAS

	defp modVista(vista,n,p,c) do
		vista = %{vista | num_vista: n};
		vista = %{vista | primario: p};
		vista = %{vista | copia: c};
		
		vista;
	end

end
