Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do
  # estado del servidor            
  defstruct num_vista: 0,
            primario: :undefined,
            copia: :undefined,
            servicio: false,
            datos: %{}

  @intervalo_latido 50

  @doc """
      Obtener el hash de un string Elixir
          - Necesario pasar, previamente,  a formato string Erlang
       - Devuelve entero
  """
  def hash(string_concatenado) do
    String.to_charlist(string_concatenado) |> :erlang.phash2()
  end

  @doc """
      Poner en marcha el servidor para gestión de vistas
      Devolver atomo que referencia al nuevo nodo Elixir
  """
  @spec startNodo(String.t(), String.t()) :: node
  def startNodo(nombre, maquina) do
    # fichero en curso
    NodoRemoto.start(nombre, maquina, __ENV__.file)
  end

  @doc """
      Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
  """
  @spec startService(node, node) :: pid
  def startService(nodoSA, nodo_servidor_gv) do
    NodoRemoto.esperaNodoOperativo(nodoSA, __MODULE__)

    # Poner en marcha el código del gestor de vistas
    Node.spawn(nodoSA, __MODULE__, :init_sa, [nodo_servidor_gv])
  end

  # ------------------- Funciones privadas -----------------------------

  def latidos(pid) do
    # Enviamos a nosotros mismos mensaje
    send(pid, :latido)
    Process.sleep(@intervalo_latido)
    latidos(pid)
  end

  def init_sa(nodo_servidor_gv) do
    Process.register(self(), :servidor_sa)
    # Process.register(self(), :cliente_gv)

    spawn(__MODULE__, :latidos, [self()])
    estado = %{num_vista: 0, primario: :undefined, copia: :undefined, servicio: false, datos: %{}}

    bucle_recepcion_principal(estado, nodo_servidor_gv)
  end

  defp bucle_recepcion_principal(estado, gv) do
    new_estado =
      receive do
        # Enviamos latido a GV
        :latido ->
          send({:servidor_gv, gv}, {:latido, estado.num_vista, Node.self()})

          {vista, service} =
            receive do
              {:vista_tentativa, vista, service} -> {vista, service}
            end

          if vista.primario == Node.self() do
            if vista.copia != estado.copia do
              if vista.copia != :undefined do
                # Si eres primario y cambia la copia, haces backup
                send({:servidor_sa, vista.copia}, {:backup, estado.datos, Node.self()})

                receive do
                  :ok -> true
                end
              end
            end
          end

          # Actualizamos estado con la vista recibida del GV
          estado = Map.put(estado, :num_vista, vista.num_vista)
          estado = Map.put(estado, :primario, vista.primario)
          estado = Map.put(estado, :copia, vista.copia)
          estado = Map.put(estado, :servicio, service)
          estado

        {:backup, x, emisor} ->
          # Backup
          estado = %{estado | datos: x}
          send({:servidor_sa, emisor}, :ok)
          estado

        {:lee, clave, cliente} ->
          # Primario o copia, si servicio=1
          if estado.servicio == true do
            valor = Map.get(estado.datos, String.to_atom(clave))

            if estado.primario == Node.self() do
              send({:cliente_sa, cliente}, {:resultado, valor})
            else
              if estado.copia == Node.self() do
                send({:cliente_sa, cliente}, {:resultado, valor})
              else
                send({:cliente_sa, cliente}, {:resultado, :no_soy_primario_valido})
              end
            end
          else
            send({:cliente_sa, cliente}, {:resultado, :no_soy_primario_valido})
          end

          estado

        {:escribe_generico, {clave, valor, con_hash}, cliente} ->
          # Primario, si servicio=1
          valor =
            if valor == nil do
              ""
            else
              valor
            end

          # No soy primario
          estado =
            if estado.primario == Node.self() do
              # No doy servicio
              if estado.servicio == true do
                valor_previo = Map.get(estado.datos, String.to_atom(clave))
                # Añadimos nuevo dato
                # Actualizamos dato
                estado =
                  if valor_previo == nil do
                    valor =
                      if con_hash == true do
                        # HASH
                        valor = hash("" <> valor)
                        valor
                      else
                        valor
                      end

                    # merge
                    nuevos_datos =
                      Map.merge(estado.datos, Map.new([{String.to_atom(clave), valor}]))

                    estado = %{estado | datos: nuevos_datos}
                    estado
                  else
                    valor =
                      if con_hash == true do
                        # HASH
                        valor = hash(valor_previo <> valor)
                        valor
                      else
                        valor
                      end

                    # update
                    nuevos_datos =
                      Map.update(
                        estado.datos,
                        String.to_atom(clave),
                        valor_previo,
                        fn valor_previo -> valor end
                      )

                    estado = %{estado | datos: nuevos_datos}
                    estado
                  end

                # Mandamos datos a copia
                send({:servidor_sa, estado.copia}, {:backup, estado.datos, Node.self()})
                timeout = 50

                receive do
                  # Mandamos resultado a cliente
                  :ok -> send({:cliente_sa, cliente}, {:resultado, valor})
                after
                  timeout ->
                    true
                    # IO.inspect("Copia Caida")
                end

                estado
              else
                estado
              end
            else
              send({:cliente_sa, cliente}, {:resultado, :no_soy_primario_valido})
              IO.inspect("No Prim")
              estado
            end

          estado
      end

    bucle_recepcion_principal(new_estado, gv)
  end
end
