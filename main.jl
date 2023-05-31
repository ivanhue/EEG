using DelimitedFiles
using Plots
using JLD # WARNING: could not import HDF5.exists into JLD
using GraphRecipes
using Statistics
push!(LOAD_PATH, ".")
using FuncionesEEG
# import Pkg; Pkg.add("Combinatorics")
# import Pkg; Pkg.add("StatsBase")


TraysPosP = 0
TraysNegP = 0
MVcsda = 0
ruta_resultados = 0


function resultados(path)
    global TraysPosP, TraysNegP, MVcsda, ruta_resultados
    # Aquí se da la dirección donde está el archivo a trabajar
    #Direccion = "C:/Users/1100423746/Dropbox/EEG/exp136_Igancio_32CH.dat"
    Direccion = path;
    Dir = split(Direccion,".")[1];
    Archivo = split(basename(Direccion),".")[1];
    Datos = readdlm( Direccion );
    ruta_resultados = joinpath(Dir * "_Resultados" );
    mkpath( ruta_resultados );
    #-----------------------------------------------------------------------------------------#
    Headers , Canales = DatosDeTodos( Datos , 2 , 3 );
    NomCan = Archivo*"_Canales.jld"
    ruta_archivo = joinpath( ruta_resultados , NomCan )
    save( ruta_archivo , Canales )
    #-------------------------------------------------------------------------------------------#
    # Funcion necesaria para encontrar los vecinos
    elementos = [ -1 0 1 ]
    combs = COMS(elementos);
    lados = [ 3 5 5 5 5 5 2 ]
    MVCuadComp = ArrayParaHeatmap( lados , Canales , Prohibidas , Coordenadas );
    NomCuad = Archivo*"_DatosEnCuadrado.jld"
    ruta_archivo = joinpath( ruta_resultados , NomCuad )
    save( ruta_archivo , "MVCuacComp" , MVCuadComp )
    MVYPromedios = PromVacios(Prohibidas,Coordenadas,combs,Headers,Canales,MVCuadComp);
    #-------------------------------------------------------------------------------------------#
    MVcsda = CSDAZapfe( MVYPromedios );
    NomCSDA = Archivo*"_CSDA.jld"
    ruta_archivo = joinpath( ruta_resultados , NomCSDA )
    save( ruta_archivo , "MVcsda" , MVcsda )
    #-------------------------------------------------------------------------------------------#
    CMP , CMN = CentrosDeMasa( MVcsda , MVcsda , 0.5 );
    NomCM = Archivo*"_CM.jld"
    ruta_archivo = joinpath( ruta_resultados , NomCM )
    save( ruta_archivo , "CMP" , CMP , "CMN" , CMN )
    #-------------------------------------------------------------------------------------------#
    DistTol = 1.5
    TTol = 3
    TraysPos = Dinamica( CMP , DistTol , TTol );
    TraysNeg = Dinamica( CMN , DistTol , TTol );
    NomTrays = Archivo*"_Trayectorias.jld"
    ruta_archivo = joinpath( ruta_resultados , NomTrays )
    save( ruta_archivo , "TP" , TraysPos , "TN" , TraysNeg )
    #-------------------------------------------------------------------------------------------#
    # El siguiente es un diccionario que contiene el inicio y final de cada trayectoria
    ( IniciosP , FinalesP ) = IniciosYFinales( TraysPos );
    ( IniciosN , FinalesN ) = IniciosYFinales( TraysNeg );
    # Ahora rellenamos los huecos que existan en las trayectorias
    TraysPos = RellenaHuecos( TraysPos , IniciosP , FinalesP );
    TraysNeg = RellenaHuecos( TraysNeg , IniciosN , FinalesN );
    # En esta sección recorremos las coordenadas y las transformamos a polares
    TraysPosP = ArreglaCoordenadas( TraysPos , lados );
    TraysNegP = ArreglaCoordenadas( TraysNeg , lados );
    NomTPs = Archivo*"_TraysPolares.jld"
    ruta_archivo = joinpath( ruta_resultados , NomTPs )
    save( ruta_archivo , "TPP" , TraysPosP , "TNP" , TraysNegP )
    return TraysPosP
end


function visualize_resultados(TraysPosP)
    global TraysPosP, TraysNegP, MVcsda, ruta_resultados
    # Generamos colores para las trayectorias para evitar que se confundan
    CTPs = [ :red1 , :lime , :orange, :cyan , :grey54 , :blue2 , :green2 , :deeppink ];
    CTP = GeneraColores( CTPs , TraysPosP );
    CTNs = [ :wheat3 , :teal , :plum, :bisque , :gray0 , :navy , :pink3 , :indigo ];
    CTN = GeneraColores( CTNs , TraysNegP );


    cachos = 15
    tamaño = size( MVcsda )[ 3 ] / cachos
    nomcsda = "CSDA_"
    nombintray = "Trayectorias_"
    nd = 2
    xylims = [ -3 3 -3 3 ]
    longtray = 5
    fr = 500
    ruta_gifs = joinpath( ruta_resultados * "gifs" );
    mkpath( ruta_gifs );
    cd( ruta_gifs )
    for i in 1:cachos
        start = Int(( tamaño * ( i - 1) + 1 ))
        finish = Int(( tamaño * i ))
        limites = extrema(MVcsda[:,:, start:finish ])
        anima = @animate for i in start:finish
            A = heatmap(MVcsda[:,:,i] , clims=limites , yflip = true )
        end
        NomGifCSDA = string( nomcsda , lpad( i , nd , "0") , ".gif" )
        gif(anima, NomGifCSDA , fps = 120);
        anima = TraysFrameXFrame(longtray , start , finish , IniciosP , FinalesP , TraysPosP 
                                , CTP , xylims, IniciosN , FinalesN , TraysNegP , CTN , fr )
        NomBinTray = string( nombintray , lpad( i , nd , "0") , ".gif" )
        gif( anima, NomBinTray , fps = 120);
    end
end


# resultados("exp136_Igancio_32CH.dat")
