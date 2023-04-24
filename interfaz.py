import customtkinter 
import logging as log
import tkinter as tk
import pythread as pt
import threading
log.basicConfig(
    level=log.INFO,
    format='%(asctime)s %(message)s',
    datefmt='%H:%M:%S'
    )

log.info(" ********** Iniciando Julia ********** ")
# Import julia to python
from julia.api import Julia
jl = Julia(compiled_modules=False)
# from julia import Main
jl.eval('include("main.jl")')
log.info(" ********** Julia iniciada **********")

customtkinter.set_appearance_mode("Dark")
customtkinter.set_default_color_theme("dark-blue")

root = customtkinter.CTk()
root.geometry("600x400")

frame = customtkinter.CTkFrame(master=root)
frame.pack(pady=20, padx=60, fill="both", expand=True)


def obtener_resultados():
    jl.eval('resultados()')


def empezar_resultados():
    log.info(" ********** Calculando resultados ********** ")
    button.configure(state="disabled")
    # threading.Thread(target=obtener_resultados).start()
    obtener_resultados()
    log.info(" ********** Termino de calcular ********** ")
    button.configure(state="normal")


label = customtkinter.CTkLabel(master=frame, text="EEG", font=("Roboto", 32))
label.pack(pady=12, padx=10)

button = customtkinter.CTkButton(master=frame, text="Calcular trayectorias", command=empezar_resultados)
button.pack(pady=12, padx=10)


    
    

if __name__ == "__main__":
    root.mainloop()





# *********** RESUTADOS: ***********

# [Done] exited with code=0 in 147.827 seconds
# [Done] exited with code=0 in 151.199 seconds
# 2.46 minutos con python
# 1 minuto con 5.3 segundos solo Julia
