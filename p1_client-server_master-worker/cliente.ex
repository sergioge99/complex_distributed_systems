################################################
# Fichero:	cliente.ex
# Autor:	755844 - Sergio Garcia Esteban & 758325 - Irene Fumanal Lacoma
# Descrip:	Cliente - Practica 1 Sistemas distribuidos
# Version:	FinalVersion
################################################

defmodule Cliente do

  def listener(cl_id) do
	receive do 
		{:result, l,t} -> IO.inspect("C Resultado recibido");
			IO.inspect(Time.diff(Time.utc_now,t,:millisecond));
	end
	listener(cl_id)
  end	

  def launch(pid, op, 1,ltn_id) do
	t1=Time.utc_now;
	send(pid, {ltn_id, op, 1..36, t1})
	IO.puts("C Lanzamos tarea")
  end

  def launch(pid, op, n,ltn_id) when n != 1 do
	t1=Time.utc_now;
	send(pid, {ltn_id, op, 1..36, t1})
	IO.puts("C Lanzamos tarea")
	launch(pid, op, n - 1,ltn_id)
  end 
  
  def genera_workload(server_pid, escenario, time,ltn_id) do
	cond do
		time <= 3 ->  launch(server_pid, :fib, 8,ltn_id); Process.sleep(2000)
		time == 4 ->  launch(server_pid, :fib, 8,ltn_id);Process.sleep(round(:rand.uniform(100)/100 * 2000))
		time <= 8 ->  launch(server_pid, :fib, 8,ltn_id);Process.sleep(round(:rand.uniform(100)/1000 * 2000))
		time == 9 -> launch(server_pid, :fib_tr, 8,ltn_id);Process.sleep(round(:rand.uniform(2)/2 * 2000))
	end
  	genera_workload(server_pid, escenario, rem(time + 1, 10),ltn_id)
  end

  def genera_workload(server_pid, escenario,ltn_id) do
  	if escenario == 1 do
		launch(server_pid, :fib, 1,ltn_id)
	else
		launch(server_pid, :fib, 4,ltn_id)
	end
	Process.sleep(2000)
  	genera_workload(server_pid, escenario,ltn_id)
  end
  

  def cliente(server_pid, tipo_escenario) do
	me=self();
	ltn_id=spawn(fn->listener(me) end);
  	case tipo_escenario do
		:uno -> genera_workload(server_pid, 1,ltn_id)
		:dos -> genera_workload(server_pid, 2,ltn_id)
		:tres -> genera_workload(server_pid, 3, 1,ltn_id)
	end
  end
end
