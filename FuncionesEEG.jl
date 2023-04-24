module FuncionesEEG

using JLD
using DelimitedFiles
using Plots
using Combinatorics
using GraphRecipes
using StatsBase

#export VarsDeDoc, DatosDeTodos, DatosUtiles, DivideDatos, EncuentraVecinos , COMS , DaCoordenadas , #MatrizDeConexiones , AñadeVacios , ArrayDeConexiones , ArrayParaHeatmap , MapaSinCeros , PromVacios #, CoordenadasProhibidas , EliminaProYNega , ArrayDePositivos , DiccionarioConDatos , Dinamica , #CuadACirc , GraficaTrayectorias , GraficaDinamica , ArreglaCoordenadas , IniciosYFinales , #RellenaHuecos , GeneraColores , TraysFrameXFrame , Coordenadas , Prohibidas

export DatosDeTodos , COMS , ArrayParaHeatmap , PromVacios , Dinamica , IniciosYFinales, RellenaHuecos , ArreglaCoordenadas , GeneraColores , TraysFrameXFrame , GeneraColores , TraysFrameXFrame , Coordenadas , Prohibidas

# Algunas extras

export Dinamica_LV, ArrayDeConexiones , MatrizDeConexiones

# Extras para 64 ch

export VarsDeDoc , DatosUtiles , DaCoordenadas , PromVacios , CoordenadasProhibidas , EliminaProYNega
export  ArrayDePositivos , DiccionarioConDatos

# Ahora las de Karel

export CSDAZapfe , CentrosDeMasa , Trayectorias

# Esta sección es para obtener las variables que contiene el documento en un diccionario
function VarsDeDoc(Datos)
    Vars = Dict{String,Any}()
    for i in 1:7
        Head = Datos[ i , : ][1]
        Head = split(Head,"[")[ 2 ]
        Head = String(split(Head,"]")[ 1 ])
        Dat = Datos[ i , : ][ 2 ]
        Vars[ Head ] = Dat
    end
    return Vars
end
#Se guarda un archivo con save("Vars_Dalia_close_190306.jld",Vars)

#Esta sección obtiene los datos de todos los canales a todos los frames sin remover nada
function DatosDeTodos( Datos , FilaHeaders , FilaDatos )
    DatosH = Datos[ FilaHeaders , : ]
    Headers = []
    for i in 1:length(DatosH)
        temp = split(DatosH[i],"]")
        if length(temp[1]) > 1
            push!(Headers,temp[1])
        end
    end
    Headers = String.(Headers)
    Canales = Dict()
    for j in 1:length(Headers)
        Canales[Headers[j]] = Float32.(Datos[FilaDatos:end,j])
    end
    return Headers , Canales
end

# Elminiamos los canales de "M1" y "M2" debido a que son referencias y reorganizamos "AF3"
function DatosUtiles( Headers , Datos )
    Headers2 = Headers[1:64]
    Numeros2 = Datos[15:end,1:64];
    ## 33 y 43 son los indices de las referencias M1 y M2
    Headers2 = Headers2[ 1:end .!= 43 ]
    Headers2 = Headers2[ 1:end .!= 33 ]
    Numeros2 = Numeros2[ : , 1:end .!= 43 ]
    Numeros2 = Numeros2[ : , 1:end .!= 33 ];
    deleteat!(Headers2,4)
    Headers2 = vcat("AF3",Headers2);
    Headers2 = String.(Headers2)
    Numeros3 = Numeros2[: , 1:end .!= 4]
    Numeros3 = hcat(Numeros2[:,4],Numeros3)
    Numeros3 = Float32.(Numeros3)
    return Headers2 , Numeros3
end

# Esta sección es para recortar en cachos del mismo tamaño los datos del frame para hacerlo
# menos pesado
function DivideDatos( Numeros , min , k , Headers , Direccion )
    Data = Numeros[ min*(k-1) + 1 : min*k , : ]
    Bin = Dict{String,Array}()
    for i in 1:length(Headers)
        Bin[Headers[i]] = Data[:,i]
    end
    return Bin
end

function EncuentraVecinos(canal,Coordenadas,Prohibidas,combinaciones,Headers)
    ValCor = values(Coordenadas)
    ValPro = values(Prohibidas)
    CoorVecinos = []
    CoorCanal = Coordenadas[canal]
    for tup in combinaciones
        temp = CoorCanal + tup
        if temp in ValCor && !(temp in ValPro)
            push!(CoorVecinos,temp)
        end
    end
    Vecinos = findall( x -> x in CoorVecinos,Coordenadas)
    indices = []
    for canal in Vecinos
        name = string(canal)
        index = findfirst(x -> x == name, Headers)
        push!(indices,index)
    end
    return Vecinos , indices
end

function DaCoordenadas( lados , Headers )  
    # Esta es una sección para dar las coordenadas de los canales
    Coordenadas = Dict()
    Prohibidas = Dict()
    dims = (length(lados),maximum(lados))
    PRN = "VACIO"
    NumCas = length(lados) * maximum(lados)
    ND = length(string(NumCas - length(Headers)))
    cv = 1
    x = 1
    y = 1
    nh = 1
    # j Es para las columnas e i es para las filas
    for i in 1:dims[1]
        Coor = []
        pre = (maximum(lados) - lados[i]) / 2
        # Esta sección es la encargada de llenar los espacios vacios
        if pre > 0 && x == 1
            for k in 1:(pre*2)
                Coor = [ Float64(y) , Float64(x) ]
                if x == pre
                    x = lados[i] + pre + 1
                else
                    x = x + 1
                end
                
                Nom = PRN*string(lpad( cv, ND, "0" ))
                
                Coordenadas[ Nom ]=Coor
                Prohibidas[ Nom ]=Coor
                cv+=1
                Coor = []
            end
            x = pre + 1
        end
        for l in 1:lados[i]
            Coor = [ Float64(y) , Float64(x) ]
            if nh <= length(Headers)
                Coordenadas[Headers[nh]] = Coor
            end
            x = x + 1
            nh+=1
            if x == pre + lados[i] + 1
                y+=1
                x = 1
            end
            Coor = []
        end
    end
    return Coordenadas , Prohibidas
end

function COMS(elementos)
    combinaciones = collect(permutations(elementos,2));
    extsup = [1 , 1]
    extinf = [ -1 , -1]
    push!(combinaciones,extsup)
    push!(combinaciones,extinf)
    return combinaciones
end

function MatrizDeConexiones( Headers , Coordenadas , Prohibidas , combinaciones )
    Conexiones = zeros( length(Headers) , length(Headers) );
    for i in 1:length(Headers)
        Vecinos , indices = EncuentraVecinos(Headers[i],Coordenadas,Prohibidas,combinaciones,Headers)
        for j in 1:length(indices)
            Conexiones[i,indices[j]]=1
        end
    end
    return Conexiones
end

function DiccionarioConDatos( Headers , Numeros )
    DatosCanales = Dict{String,Array}()
    for i in 1:length(Headers)
        DatosCanales[ Headers[ i ] ] = Numeros[:,i]
    end
    return DatosCanales
end

function ArrayDeConexiones( BIN01 , Headers )
    MV = []
    frames = length(BIN01["OZ"])
    for i in 1:frames
        MF = []
        for j in 1:length(Headers)
            d = BIN01[Headers[j]][i]
            push!(MF,d)
        end
        push!(MV,Float32.(MF))
    end
    return MV
end

function ArrayParaHeatmap( lados , BIN01 , Prohibidas , Coordenadas )
    h = length(lados)
    l = maximum(lados)
    z = length(BIN01["OZ"])
    MVCuadradoCompleto = zeros(h,l,z)
    P = keys(Prohibidas)
    for k in 1:z
        for i in 1:h , j in 1:l
            ubi = [ i , j ]
            Can = findfirst( x -> x == ubi , Coordenadas )
            if !(Can in P)
                MVCuadradoCompleto[ i , j , k ] = BIN01[Can][k]
            end
        end
    end
    return MVCuadradoCompleto
end

function MapaSinCeros( MVCuadradoCompleto , frame , umbral )
    MVCuadradoCompleto2 = copy(MVCuadradoCompleto)
    Dimensiones = size( MVCuadradoCompleto2[ : , : , frame ] )
    for i in 1:Dimensiones[1], j in 1:Dimensiones[2]
        if MVCuadradoCompleto2[ i , j , frame ] < umbral
            MVCuadradoCompleto2[ i , j , frame ] = umbral
        end
    end
    Map = heatmap( MVCuadradoCompleto2[ : , : , frame ] )
    return Map
end



function PromVacios( Prohibidas , Coordenadas , combinaciones , Headers , BIN01 , MVCuadradoCompleto )
    CoorPro = collect(keys(Prohibidas));
    VecinosDePro = Dict()
    for ν in 1:length(CoorPro)
        vecinos , indices=EncuentraVecinos(CoorPro[ν],Coordenadas,Prohibidas,combinaciones,Headers)
        VecinosDePro[CoorPro[ν]] = vecinos
    end
    # Hacemos cero todos los valores de los canales prohibidos
    MVConPromedios = copy( MVCuadradoCompleto )
    P = keys(Prohibidas)
    for k in 1:size( MVCuadradoCompleto )[3]
        for i in 1:8 , j in 1:9
            ubi = [ i , j ]
            Can = findfirst( x -> x == ubi , Coordenadas )
            if Can in P
                Vecinos = VecinosDePro[Can]
                Temp = []
                promed = 0
                for ξ in 1:length(Vecinos)
                    push!(Temp,BIN01[Vecinos[ξ]][k])
                    promed = mean(Temp)
                end
                MVConPromedios[ i , j , k ] = promed
            end
        end
    end
    return MVConPromedios
end

function CoordenadasProhibidas( Prohibidas )
    # Convertimos las coordenadas a enteros para las iteraciones
    CoorPro = collect(values(Prohibidas));
    for i in 1:length(CoorPro)
        CoorPro[i] = Int.(CoorPro[i])
    end
    return CoorPro
end

function EliminaProYNega( MVcsda , Prohibidas , Coordenadas )
    
    # Hacemos cero todos los valores de los canales prohibidos
    MVcsda2 = copy(MVcsda)
    P = keys(Prohibidas)
    for k in 1:size(MVcsda)[3]
        for i in 1:8 , j in 1:9
            ubi = [ j , i ]
            Can = findfirst( x -> x == ubi , Coordenadas )
            if Can in P
                MVcsda2[ i , j , k ] = 0
            end
        end
    end
    # Igualamos a cero los valores negativos ya que se vieron muy afectados por los prohibidos
    for k in 1:size(MVcsda)[3]
        for i in 1:8 , j in 1:9
            if MVcsda2[ i , j , k ] < 0
                MVcsda2[ i , j , k ] = 0
            end
        end
    end
    
    return MVcsda2
end

function ArrayDePositivos( MVcsdaListo )
    DatosPositivos = []
    for k in 1:size( MVcsdaListo )[3]
        for i in 1:8 , j in 1:9
            if MVcsdaListo[ i , j , k ] > 0
                push!(DatosPositivos, MVcsdaListo[ i , j , k ])
            end
        end
    end
    
    return DatosPositivos
end
    
function dist2D(x,y)
    result=sqrt((x[1]-y[1])^2+(x[2]-y[2])^2)
    return result
end

# Funcion que encuentra las distancias entre las posiciones x y y de un vector con todos los elementos de una
# matriz
# v es el vector donde v[1] y v[2] son las posiciones en x y y, M es la matriz
function dist2DVector(v,M)
    dist = sqrt.( ( v[ 1 ] .- M[ :, 1 ] ) .^ 2 .+ ( v[ 2 ] .- M[ :, 2 ] ) .^ 2 );
    return dist
end


#Establecemos una función que nos dará los conjuntos en el frame que superen el peso mínimo
# Frame es la matriz con los datos de los conjuntos en cierto frame con la forma nx3
function DaConsiderables(Frame,PesoMin)
    NF = size(Frame)[1]
    if NF > 0
        Pesos = Frame[:,3]
        EncuentraConsiderables = findall(abs.(Pesos) .> PesoMin)
        Considerables = Frame[ EncuentraConsiderables,:]
    else
        Considerables = Frame
    end
    return Considerables
end

# Encuentra si en el siguiente frame hay una continuidad en la trayectoria, la añade y borra el dato
function EncuentraConcatenaYBorra( Trayectoria , Positivos , tiempo , DistTol, 
    HayMas , TExtra , TTol , TodasTrayectorias , ContadorTrayectorias )
    ultimo = Trayectoria[end,:]
    distancias = dist2DVector(ultimo,Positivos[ tiempo + 1 ])
    MasCercano = argmin(distancias)
    DistMasCercano = minimum(distancias)
    if DistMasCercano < DistTol
        Temporal = [ transpose(Positivos[ tiempo + 1 ][ MasCercano , : ]) tiempo + 1 ]
        Cadena = vcat( Trayectoria , Temporal)
        Positivos[ tiempo + 1 ] = Positivos[ tiempo + 1 ][ 1:end .!= MasCercano, : ]
        TExtra = 0
    else
        Cadena = Trayectoria
        if TExtra == TTol
            HayMas = false
            if size( Trayectoria )[ 1 ] > 1
                TodasTrayectorias[ ContadorTrayectorias ] = Trayectoria
                ContadorTrayectorias+=1
            end
        end
        TExtra+=1
    end
    return Cadena , Positivos , HayMas , TExtra , TodasTrayectorias , ContadorTrayectorias
end
    
function Dinamica( Positivos2 , DistTol , TTol )
    Positivos = copy(Positivos2)
    TotalFrames = length(Positivos)
    for k in 1:5
        Positivos[ TotalFrames + k ] = Array{Float64}(undef, 0, 3)
    end
    UltimoFrame = false
    pesomin=0
    TodasTrayectorias = Dict{Integer, Array{Any}}()
    ContadorTrayectorias = 1
    for tiempo in 1:TotalFrames
        if tiempo == TotalFrames
            UltimoFrame = true
        end
        ConjEnFrame = DaConsiderables( Positivos[ tiempo ], pesomin )
        NumConj = size( ConjEnFrame )[1]
        if NumConj > 0        
            # Realizamos el procedimiento para cada uno de los conjuntos
            for j in 1:NumConj
                if tiempo < TotalFrames
                    UltimoFrame = false
                end
                tiempoprimo = tiempo    
                HayMas = true
                ConjConFrame = [ transpose( ConjEnFrame[ j , : ] ) tiempo ]
                Trayectoria = ConjConFrame
                TExtra = 0
                while HayMas == true && TExtra <= TTol
                    if tiempoprimo >= TotalFrames
                        UltimoFrame = true
                    end                
    #POR AHORA DEJO PASAR PERO PARA EVITAR ERRORES DEBEMOS BORRAR PESOS QUE NO SON CONSIDERABLES
                    if tiempoprimo < TotalFrames
                        ConjEnSigFrame = DaConsiderables( Positivos[ tiempoprimo + 1 ] , pesomin )
                        NumConjSig = size( ConjEnSigFrame )[ 1 ]
                    else
                        NumConjSig = 0
                        TExtra = TTol
                    end
                    if NumConjSig > 0
                        # Esta es la linea más peligrosa, si esto funciona entonces =) 
                        (Trayectoria,Positivos,HayMas,TExtra,TodasTrayectorias 
                            , ContadorTrayectorias) = EncuentraConcatenaYBorra( 
                            Trayectoria , Positivos , tiempoprimo , DistTol, HayMas, 
                            TExtra , TTol  , TodasTrayectorias , ContadorTrayectorias )
                        if UltimoFrame == true
                            if size( Trayectoria )[1] > 1
                                TodasTrayectorias[ ContadorTrayectorias ] = Trayectoria
                                ContadorTrayectorias+=1
                                HayMas = false
                            end
                        end
                        tiempoprimo+=1
                    else
                        if TExtra == TTol
                            if size( Trayectoria )[ 1 ] > 1
                                TodasTrayectorias[ ContadorTrayectorias ] = Trayectoria
                                ContadorTrayectorias+=1
                                HayMas = false
                            else
                                HayMas = false
                            end
                        end
                        TExtra+=1
                        tiempoprimo+=1
                    end
                end # Cierra el while que ve si hay más 
            end # Cierra el for de cada conjunto
        end  # Cierra el if de si hay conjuntos en del frame
    end # Cierra el for de todos los frames
    return TodasTrayectorias
end
    
    
    
function CuadACirc(puntos)
    PuntosPolares = zeros( size(puntos)[1] ,2)
    for i in 1:size(puntos)[1]
        # Si el ancho es más grande que el largo
        if abs(puntos[i,1]) > abs(puntos[i,2])
            r = abs(puntos[i,1])
            # Si el signoA es positivo está a la derecha, si es negativo a la izquierda
            signoA = puntos[i,1]/abs(puntos[i,1])
            # Si el signoL es positivo está arriba, si es negativo abajo
            signoL = puntos[i,2]/abs(puntos[i,2])
            # Ahora toca transformar las coordenadas del punto menor a radianes
            θ = puntos[i,2]/r*(π/4)
            if signoA < 0
                θ = θ + (π)
            end
        elseif abs(puntos[i,2]) > abs(puntos[i,1])
            r = abs(puntos[i,2])
            # Si el signoA es positivo está a la derecha, si es negativo a la izquierda
            signoA = puntos[i,1]/abs(puntos[i,1])
            # Si el signoL es positivo está arriba, si es negativo abajo
            signoL = puntos[i,2]/abs(puntos[i,2])
            # Ahora toca transformar las coordenadas del punto menor a radianes
            θ = puntos[i,1]/r*(π/4)
            if signoL > 0 
                θ = -θ + (π/2)
            elseif signoL < 0 
                θ = -θ + (3*π/2)
            end
        else
            r = abs(puntos[i,2])
            signoA = puntos[i,1]/abs(puntos[i,1])
            # Si el signoL es positivo está arriba, si es negativo abajo
            signoL = puntos[i,2]/abs(puntos[i,2])
            if signoL > 0 
                if signoA < 0
                    # Extremo superior izquierdo
                    θ = puntos[i,2]/r*(π/4)+(π/2)
                else
                    # Extremo superior derecho
                    θ = puntos[i,2]/r*(π/4)
                end
            else
                if signoA < 0
                    # Extremo inferior izquierdo
                    θ = puntos[i,2]/r*(π/4)+(6*π/4)
                else
                    # Extremo inferior derecho
                    θ = puntos[i,1]/r*(π/4)+(6*π/4)
                end
            end
        end
        ( x , y ) = polar2cartesian(r, θ)
        PuntosPolares[ i , 1 ] = x
        PuntosPolares[ i , 2 ] = y
    end
    return PuntosPolares
end
function polar2cartesian(r, θ)
    x = r * cos(θ)
    y = r * sin(θ)
    return (x, y)
end
    
    
function GraficaTrayectorias( TraysPos, i , primero , minx , maxx , miny , maxy )
    if i == primero
        p = plot(
                TraysPos[i][:,1],TraysPos[i][:,2],line=(:dot,1),
                marker=([:square :d],5,0.8,stroke(3,:gray)),  
                xlims = ( minx , maxx ) , ylims = ( miny , maxy ),
                leg=false
                )
    else
        p = plot!(
                TraysPos[i][:,1],TraysPos[i][:,2],line=(:dot,1),
                marker=([:square :d],5,0.8,stroke(3,:gray)),  
                xlims = ( minx , maxx ) , ylims = ( miny , maxy ),
                leg=false
                )
    end
    return p
end
    
function GraficaDinamica( c , frame , longtray , Origen , inicio , final , cg , xylims , fr)
    if frame - inicio + 1  < longtray
        x = Origen[1:Int(frame-inicio+1),1]
        y = Origen[1:Int(frame-inicio+1),2]
    elseif frame < final - longtray && frame >= longtray
        x = Origen[Int(frame-inicio+1):Int(frame-inicio+1+longtray),1]
        y = Origen[Int(frame-inicio+1):Int(frame-inicio+1+longtray),2]
    else
        x = Origen[Int(frame-inicio+1):end,1]
        y = Origen[Int(frame-inicio+1):end,2]
    end
    if c == 1
        A = plot(
            x , y , color = cg
            ,line=(:dot,1), lab=frame/fr,
            marker=([:square :d],5,0.8,stroke(3,:gray)),  
            xlims = ( xylims[1] , xylims[2] ) , ylims = ( xylims[3] , xylims[4] ),
            #leg=false
            )
    else 
        A = plot!(
            x , y , color = cg
            ,line=(:dot,1), lab=frame/fr,
            marker=([:square :d],5,0.8,stroke(3,:gray)),  
            xlims = ( xylims[1] , xylims[2] ) , ylims = ( xylims[3] , xylims[4] ),
            #leg=false
            )
    end
    return A
end
    
function ArreglaCoordenadas( TraysPos , lados )
    for i in 1:length(TraysPos)
        # Primero recorremos los puntos en el eje x los cuales están en el rango [1,5]
        TraysPos[ i ][:,1] = TraysPos[ i ][:,1] .- ( ( maximum( lados ) - 1 ) / 2 + 1 )
        TraysPos[ i ][:,2] = TraysPos[ i ][:,2] .- ( ( length( lados ) - 1 ) / 2 + 1 )
        TraysPos[ i ][:,1] = TraysPos[ i ][:,1]./maximum( lados ).*length( lados )
        TraysPos[ i ][:,1:2] = CuadACirc( TraysPos[ i ][:,1:2] )  #PuntosPolares
    end
    return TraysPos
end

function IniciosYFinales( TraysPos )
    Inicios = Dict{Int,Float64}()
    for i in 1:length(TraysPos)
        Inicios[i] = TraysPos[i][1,end]
    end
    Finales = Dict{Int,Float64}()
    for i in 1:length(TraysPos)
        Finales[i] = TraysPos[i][end,end]
    end
    return Inicios , Finales
end

function RellenaHuecos( TP2 , Inicios , Finales)
    for i in 1:length(TP2)
        if (Finales[i]-Inicios[i]) + 1 != size(TP2[i])[1]
            Frames = TP2[i][:,end]
            for j in 1:(size(TP2[i])[1]-1)
                dif = Frames[j+1] - Frames[j]
                if dif > 1
                    Cabeza = TP2[i][1:j,:]
                    Tronco = TP2[i][j+1:end,:]
                    for k in 1:dif-1
                        h1 = (TP2[i][j,1]+(TP2[i][j+1,1]-TP2[i][j,1])*(k/dif))
                        h2 = (TP2[i][j,2]+(TP2[i][j+1,2]-TP2[i][j,2])*(k/dif))
                        h3 = (TP2[i][j,3]+(TP2[i][j+1,3]-TP2[i][j,3])*(k/dif))
                        h4 = (Inicios[i]+j+k-1)
                        Añadido = [ h1 h2 h3 h4 ]
                        Cabeza = vcat(Cabeza,Añadido)
                    end
                    TP2[i] = vcat(Cabeza,Tronco)
                end
            end
        end
    end
    return TP2
end

function GeneraColores( CTs , TP2 )
    CTP = Dict()
    LG = length(CTs)
    cc = 0
    for i in 1:length(TP2)
        cc+=1
        CTP[ i ] = CTs[cc]
        if cc == LG
            cc = 0
        end
    end
    return CTP
end
    
function TraysFrameXFrame( longtray , F1 , FF , IniciosP , FinalesP , TP2 , CTP , xylims
                           , IniciosN , FinalesN , TN2 , CTN  , frecuencia )
    ActivosP = Dict()
    ActivosN = Dict()
    PON = [ :square :triangle ]
    anima = @animate for frame in F1:FF
        TempInP = findall(x->x==frame,IniciosP)
        for i in TempInP
            ActivosP[ i ] = [ TP2[i][:,1] , TP2[i][:,2] ]
        end
        TempFinP = findall(x->x==frame,FinalesP)
        for i in TempFinP
            delete!(ActivosP,i)
        end
        ValActP = sort(collect(keys(ActivosP)));
        c = 0
        for i in 1:length(ValActP)
            c+=1
            #println(PON[1])
            A = GraficaDinamica(c,frame,longtray,TP2[ValActP[i]]
                ,IniciosP[ValActP[i]],FinalesP[ValActP[i]],CTP[ValActP[i]]
                , xylims , frecuencia )
        end
#-------------------------------------------------------------------------------------------#
        TempInN = findall(x->x==frame,IniciosN)
        for i in TempInN
            ActivosN[ i ] = [ TN2[i][:,1] , TN2[i][:,2] ]
        end
        TempFinN = findall(x->x==frame,FinalesN)
        for i in TempFinN
            delete!(ActivosN,i)
        end
        ValActN = sort(collect(keys(ActivosN)));
        d = 0
        for i in 1:length(ValActN)
            d+=1
            A = GraficaDinamica(c,frame,longtray,TN2[ValActN[i]]
                ,IniciosN[ValActN[i]],FinalesN[ValActN[i]],CTN[ValActN[i]]
                , xylims , frecuencia )
        end
    end
    return anima
end
    
    
    
#En la parte derecha van las filas y en la izquierda las columnas
Coordenadas = Dict{String,Array}(
    "VACIO01" => [ 1 , 1 ],
    "FP1" => [ 1 , 2 ],
    "VACIO02" => [ 1 , 3 ],
    "FP2" => [ 1 , 4 ],
    "VACIO03" => [ 1 , 5 ],
    "F7" => [ 2 , 1 ],
    "F3" => [ 2 , 2 ],
    "FZ" => [ 2 , 3 ],
    "F4" => [ 2 , 4 ],
    "F8" => [ 2 , 5 ],
    "FT7" => [ 3 , 1 ],
    "FC3" => [ 3 , 2 ],
    "FCZ" => [ 3 , 3 ],
    "FC4" => [ 3 , 4 ],
    "FT8" => [ 3 , 5 ],
    "T7" => [ 4 , 1 ],
    "C3" => [ 4 , 2 ],
    "CZ" => [ 4 , 3 ],
    "C4" => [ 4 , 4 ],
    "T8" => [ 4 , 5 ],
    "TP7" => [ 5 , 1 ],
    "CP3" => [ 5 , 2 ],
    "CPZ" => [ 5 , 3 ],
    "CP4" => [ 5 , 4 ],
    "TP8" => [ 5 , 5 ],
    "P7" => [ 6 , 1 ],
    "P3" => [ 6 , 2 ],
    "PZ" => [ 6 , 3 ],
    "P4" => [ 6 , 4 ],
    "P8" => [ 6 , 5 ],
    "VACIO04" => [ 7 , 1 ],
    "O1" => [ 7 , 2 ],
    "OZ" => [ 7 , 3 ],
    "O2" => [ 7 , 4 ],
    "VACIO05" => [ 7 , 5 ]
);
    
    
    
Prohibidas = Dict{String,Array}(
    "VACIO01" => [ 1 , 1 ],
    "VACIO02" => [ 1 , 3 ],
    "VACIO03" => [ 1 , 5 ],
    "VACIO04" => [ 7 , 1 ],
    "VACIO05" => [ 7 , 5 ]);


function UltimasVelocidades( Ts , Locs , frame  )
    x = Locs[ frame - 1 , : ]
    y = Locs[ frame , : ]
    ΔLoc = dist2D(x,y)
    ΔT = Ts[ frame ] - Ts[ frame  - 1 ]
    V = ΔLoc / ΔT
    return V , ΔT
end

function ECYB_Limites_Variables( Trayectoria , Positivos , tiempo , DistTol1 , 
    HayMas , TExtra , TTol , TodasTrayectorias , ContadorTrayectorias )
    # Lo que debo hacer ahora es tomar los últimos 4 elementos de la trayectoria
    if size(Trayectoria)[1] < 5
        DistTol = DistTol1
    else
        Locs = Trayectoria[ ( end - 4 ) : ( end ) , [ 1 , 2 ] ]
        Ts = Trayectoria[ ( end - 4 ) : ( end ) , 4 ]
        ArrVel = []
        for frame in 2:5
            ( V , ΔT ) = UltimasVelocidades( Ts , Locs , frame  )
            push!( ArrVel , V )
        end
        Ts = Ts[2:end]
        X2 = zeros( 4 ,2);
        X2[:,1] = transpose(Ts);  
        X2[:,2] .= 1.0
        ArrVel = Float64.( ArrVel )
        coeff_pred = X2\ArrVel
        DistTol = ( coeff_pred[1]*(Ts[end]+1)+coeff_pred[2])*1.5
        if DistTol < DistTol1/5
            DistTol = DistTol1/5
        end
    end
    ultimo = Trayectoria[end,:]
    distancias = dist2DVector(ultimo,Positivos[ tiempo + 1 ])
    MasCercano = argmin(distancias)
    DistMasCercano = minimum(distancias)
    if DistMasCercano < DistTol
        Temporal = [ transpose(Positivos[ tiempo + 1 ][ MasCercano , : ]) tiempo + 1 ]
        Cadena = vcat( Trayectoria , Temporal)
        Positivos[ tiempo + 1 ] = Positivos[ tiempo + 1 ][ 1:end .!= MasCercano, : ]
        TExtra = 0
    else
        Cadena = Trayectoria
        if TExtra == TTol
            HayMas = false
            if size( Trayectoria )[ 1 ] > 1
                TodasTrayectorias[ ContadorTrayectorias ] = Trayectoria
                ContadorTrayectorias+=1
            end
        end
        TExtra+=1
    end
    return Cadena , Positivos , HayMas , TExtra , TodasTrayectorias , ContadorTrayectorias
end
function Dinamica_LV( Positivos2 , DistTol1 , TTol )
    Positivos = copy(Positivos2)
    TotalFrames = length(Positivos)
    for k in 1:5
        Positivos[ TotalFrames + k ] = Array{Float64}(undef, 0, 3)
    end
    UltimoFrame = false
    pesomin=0
    TodasTrayectorias = Dict{Integer, Array{Any}}()
    ContadorTrayectorias = 1
    for tiempo in 1:TotalFrames
        if tiempo == TotalFrames
            UltimoFrame = true
        end
        ConjEnFrame = DaConsiderables( Positivos[ tiempo ], pesomin )
        NumConj = size( ConjEnFrame )[1]
        if NumConj > 0        
            # Realizamos el procedimiento para cada uno de los conjuntos
            for j in 1:NumConj
                if tiempo < TotalFrames
                    UltimoFrame = false
                end
                tiempoprimo = tiempo    
                HayMas = true
                ConjConFrame = [ transpose( ConjEnFrame[ j , : ] ) tiempo ]
                Trayectoria = ConjConFrame
                TExtra = 0
                while HayMas == true && TExtra <= TTol
                    if tiempoprimo >= TotalFrames
                        UltimoFrame = true
                    end                

                    if tiempoprimo < TotalFrames
                        ConjEnSigFrame = DaConsiderables( Positivos[ tiempoprimo + 1 ] 
                                                        , pesomin )
                        NumConjSig = size( ConjEnSigFrame )[ 1 ]
                    else
                        NumConjSig = 0
                        TExtra = TTol
                    end
                    if NumConjSig > 0
                        # Esta es la linea más peligrosa, si esto funciona entonces =) 
                        ( Trayectoria , Positivos , HayMas , TExtra , TodasTrayectorias 
                            , ContadorTrayectorias ) = ECYB_Limites_Variables( 
                            Trayectoria , Positivos , tiempoprimo , DistTol1 , HayMas, 
                            TExtra , TTol  , TodasTrayectorias , ContadorTrayectorias )
                        if UltimoFrame == true
                            if size( Trayectoria )[1] > 1
                                TodasTrayectorias[ ContadorTrayectorias ] = Trayectoria
                                ContadorTrayectorias+=1
                                HayMas = false
                            end
                        end
                        tiempoprimo+=1
                    else
                        if TExtra == TTol
                            if size( Trayectoria )[ 1 ] > 1
                                TodasTrayectorias[ ContadorTrayectorias ] = Trayectoria
                                ContadorTrayectorias+=1
                                HayMas = false
                            else
                                HayMas = false
                            end
                        end
                        TExtra+=1
                        tiempoprimo+=1
                    end
                end # Cierra el while que ve si hay más 
            end # Cierra el for de cada conjunto
        end  # Cierra el if de si hay conjuntos en del frame
    end # Cierra el for de todos los frames
    return TodasTrayectorias
end





























#----------------------------- FUNCIONES DE KAREL QUE QUIERO CAMBIAR -------------------------------#


"""
    CSDAZapfe( Data::Matrix{Float64} )
        -> GST::Matrix{Float16}, GS::Matrix{Float116}, CSD::Matrix{Float64}
        using GaussSuavizarTemporal, GaussianSmooth, DiscreteLaplacian
"""
function CSDAZapfe( Data )
    #nChsl, nChsh, nFrs = size( Data );
    #side = Int( sqrt( nChs ) );
    #Data3D = reshape( Data, nChsl, nChsh, nFrs );
    ( μ, ν, ι )  = size( Data );
    # We apply a Temporal Gaussian smoothing ( this greatly affects the animations )
    Data3Plain = zeros( μ, ν, ι );
    for j = 1 : μ, l = 1 : ν
        channel = vec( Data[ j, l, : ] );
        Data3Plain[ j, l, : ] = GaussSuavizarTemporal( channel );
    end
    Φ = zeros( μ, ν, ι );
    ∇ = zeros( μ, ν, ι );
    # We spatially smooth the LFP with a two-dimensional Gaussian filter.
    # Later we obtain the dCSD.
    for τ = 1 : ι
        Φ[ :, :, τ ] = GaussianSmooth( Data3Plain[ :, :, τ ] );
        ∇[ :, :, τ ] = DiscreteLaplacian( Φ[ :, :, τ ] );
    end
    ∇ = -1 * ∇;
    return ∇
end      

function UnNormGauss(x,sigma)
    return exp(-x*x/(2*sigma))
end

function GaussSuavizarTemporal(Datos,Sigma=3)
    #Un suavizado Gaussiano temporal.
    #Esto es escencialmente un filtro pasabajos.
    #Depende implicitamente de la frecuencia de muestreo.
    #sigma esta medido en pixeles, es la desviacion estandar de nuestro kernel.
    #El medioancho de nuestra ventana seran 3*sigma

    medioancho=ceil(Sigma*3)
    colchon=ones(medioancho)
    result=zeros(size(Datos))
    datoscolchon=vcat(colchon*Datos[1], Datos, colchon*Datos[end])
    kernel=map(x->UnNormGauss(x,Sigma), collect(-medioancho:medioancho))
    kernel=kernel/(sum(kernel))
                
    #La convolucion asi normalizada preserva el valor RELATIVO entre los puntos de la funcion.
    for t=medioancho+1:length(Datos)+medioancho
        result[t-medioancho]=sum(datoscolchon[t-medioancho:t+medioancho].*kernel)
    end
 
    return result
end

GaussianKernel=[0.00000067	0.00002292	0.00019117	0.00038771	0.00019117	0.00002292	0.00000067
0.00002292	0.00078634	0.00655965	0.01330373	0.00655965	0.00078633	0.00002292
0.00019117	0.00655965	0.05472157	0.11098164	0.05472157	0.00655965	0.00019117
0.00038771	0.01330373	0.11098164	0.22508352	0.11098164	0.01330373	0.00038771
0.00019117	0.00655965	0.05472157	0.11098164	0.05472157	0.00655965	0.00019117
0.00002292	0.00078633	0.00655965	0.01330373	0.00655965	0.00078633	0.00002292
0.00000067	0.00002292	0.00019117	0.00038771	0.00019117	0.00002292	0.00000067]

function GaussianSmooth(Datos)
    tamanodatos=size(Datos)
    result=zeros(tamanodatos)
    temp=copy(Datos)
    (mu, lu)=size(Datos)
    #Primero, hacemos el padding con copia de los datos para que no se suavice demasiado
    ## Okey, parece que los imbeciles de rioarriba cambiaron la sintaxis de
    # rebanadas de matriz. Ahora CUALQUIER rebanada de matriz es colvec.
    arriba=reshape(temp[1,:],(1,lu))
    abajo=reshape(temp[end,:],(1,lu))
    arr3=vcat(arriba,arriba,arriba)
    aba3=vcat(abajo,abajo,abajo)   
    temp=vcat(arr3, temp, aba3) 
    for j=1:3
        temp=hcat(temp[:,1], temp, temp[:,end])
    end
    for j=4:tamanodatos[1]+3, k=4:tamanodatos[2]+3
        #los indices van primero, "renglones", luego "columnas", etc
        aux=temp[j-3:j+3,k-3:k+3]
        result[j-3,k-3]=sum(GaussianKernel.*aux)
    end
    #Esta convolución no respeta norma L2
    #result=result*maximum(abs(Datos))/maximum(abs(result))
    return result
end

#El operador de Laplace-Lindenberg
LaplacianTerm1=[[0 1 0]; [1 -4 1]; [0 1 0]]
LaplacianTerm2=[[0.5 0 0.5]; [0 -2 0]; [0.5 0 0.5]]
LaplacianKernel=(1-1/3)*LaplacianTerm1+(1/3)*LaplacianTerm2

function DiscreteLaplacian(Datos)
    
    # A: Me parece que hasta el siguiente comentario no son utiles las lineas#
    temp=copy(Datos)
    (mu,lu)=size(Datos)
    izq=reshape(temp[1,:],(1,lu))
    der=reshape(temp[end,:],(1,lu)) 
    #-------------------------------
    #Primero, hacemos el padding con copia de los datos para que no se suavice demasiado
    temp=vcat(izq, temp, der)
    temp=hcat(temp[:,1], temp, temp[:,end])
    largo,ancho=size(temp)
    aux=Array{Float32}(undef, 3,3)
    result=zeros(size(temp))    
        
    # A: En esta parte lo que se hace es calcular el CSD aplicando el Kernel laplaciano a cada celda más su 8Vecindad y posteriormente suma todos los resultados como valor de la celda
    for j=2:largo-1, k=2:ancho-1
        #los indices van primero, "renglones", luego "columnas", etc
        aux=temp[j-1:j+1,k-1:k+1]
        result[j,k]=sum(LaplacianKernel.*aux)
    end
    #DO  Crop the borders
    result=result[2:end-1,2:end-1]
    return result
end
    
function CentrosDeMasa( csda , DatosPositivos , factor = 1 )
        
    (ancho,alto,nmax)=size(csda)
    (mincsd,maxcsd)=extrema(DatosPositivos)
    ϵ=max(abs(mincsd),abs(maxcsd))/100
    scsd=std(DatosPositivos)
    umbrsep=factor*scsd
    #umbrsepnota=round(umbrsep, digits=4)

    (CMP, CMN)=ObtenComponentesyCM(csda,1,nmax,umbrsep);
       
    return CMP , CMN

end

function TiraOrillas(Puntos::Set)
    #Descarta lo que se sale de la malla de electrodos
    result=Set([])
    for p in Puntos
        if !(p[1]==0 || p[2]==0 || p[1]==65 ||  p[2]==65)
            push!(result,p)
           # println("Añadiendo ", p, " al result") 
        end
    end
    return result
end


function vecindad8(punto::Array)
    # La ocho-vecindad de un punto en una malla cuadrada.
    j=punto[1]
    k=punto[2]
    result=Set{Array{Int64,1}}()
    push!(result, [j-1,k-1])
    push!(result, [j-1,k])
    push!(result, [j-1,k+1])
    push!(result, [j,k-1])
    push!(result, [j,k+1])
    push!(result, [j+1,k-1])
    push!(result, [j+1,k])
    push!(result, [j+1,k+1])
    result=TiraOrillas(result)
    return result
end

function ComponentesSP(DatosSignados::Array)
    #Single pass method for Disjoint Components.
    lista=copy(DatosSignados)
    componentes=Set{Any}()
    while(length(lista)!=0)
        
        x=pop!(lista) #arranca el ULTIMO elemento de la lista
        listaprofundeza=Array{Int64}[]
        componentecurlab=Array{Int64}[]
        push!(listaprofundeza, x) #Pone elementos al FINAL de la lista
        push!(componentecurlab, x)    
        profundidad=0
        
        while ((length(listaprofundeza)!=0) && profundidad<1000)

            y=pop!(listaprofundeza)
            for v in vecindad8(y)
                if in(v, lista) # A: Si v está en la lista
                    deleteat!(lista, indexin(Any[v], lista))
                    push!(listaprofundeza, v) 
                    profundidad+=1
                    push!(componentecurlab, v)
                end
            end
        end
        push!(componentes, componentecurlab)    
    end
    return componentes
end

function ObtenComponentesyCM(Datos::Array, tini=1,tfini=tmax, epsilon=1.0)
    #CSD ahora no tiene orillas. Asi que toca adaptarse.
    (alto,ancho,lu)=size(Datos)
    #la cantidad minima de pixeles que tiene que tener un componente para
    #que lo tomemeos en cuenta
    tamano=3
    #Esto va a a ser el resultado de la funcion!
    #La llave es t
    #El contenido es la lista de CM.
    CMPositivo=Dict{Int, Array}()
    CMNegativo=Dict{Int, Array}()
    #Aqui empieza el circo
    for t=tini:tfini
        #iniciar variables vacias
        ActividadNegativa=Array{Int16}[]
        ActividadPositiva=Array{Int16}[]
        SpikeCountPositivo=zeros(alto,ancho)
        SpikeCountNegativo=zeros(alto,ancho)
        #Separamos pixeles positivos y negativos
        for j=1:alto,k=1:ancho
            # A: Obtenemos el valor de Datos[j,k,t] y vemos si supera los umbrales de actividad positiva o negativa
            if(Datos[j,k,t]<-epsilon)
                push!(ActividadNegativa, [j, k])
                SpikeCountNegativo[j,k]+=1
            elseif(Datos[j,k,t]>epsilon)
                push!(ActividadPositiva, [j, k])
                SpikeCountPositivo[j,k]+=1
            end
        end
            #Primero Negativo
        componentesneg=ComponentesSP(ActividadNegativa)
        centrosdemasaneg=[[0 0 0];]
            #=
        componentesneg/pos son
            conjuntos con las listas de elemenentos de los
        componentes en un instante dado. Se tiene que "cerar" siempre. 
       =#
        
        for p in componentesneg
            # A: Mu es el tamaño total del array, es decir cuantos pixeles hay
            mu=length(p)        
            if mu>tamano
                masa=0.00
                x=0.00
                y=0.00
                for q in p
                    j=q[1]
                    k=q[2]
                    masalocal=Datos[j,k,t]
                    masa+=masalocal
                    x+=k*masalocal          
                    y+=j*masalocal
                end
                x/=masa                    # A: Ahora x es igual a x/masa
                y/=masa
                A=[x y masa]               # A: A son los datos del centro de masa del conjunto actualvcat(centrosdemasaneg, A)
                centrosdemasaneg=vcat(centrosdemasaneg, A)
            end
        end
        centrosdemasaneg=centrosdemasaneg[2:end,:]
        CMNegativo[t]=centrosdemasaneg
        ##### Ahora lo posittivo (fuentes)
        # A: Esto es lo mismo pero para las partes negativas
        componentespos=ComponentesSP(ActividadPositiva)               
        centrosdemasapos=[[0 0 0];]
        for p in componentespos
            mu=length(p)
            if mu>tamano
                masa=0.00
                x=0.00
                y=0.00
                for q in p
                    j=q[1]
                    k=q[2]
                    masalocal=Datos[j,k,t]
                    masa+=masalocal
                    x+=k*masalocal
                    y+=j*masalocal
                end
                x/=masa 
                y/=masa
                A=[x y masa]
                centrosdemasapos=vcat(centrosdemasapos, A)
            end
        end
        centrosdemasapos=centrosdemasapos[2:end,:]       
        CMPositivo[t]=centrosdemasapos
    end
    return (CMPositivo, CMNegativo)
end

function Trayectorias( CMP , CMN , frecuencia )
    evocada=false # if its electro stimulated activity set to true.
    nmax=length( CMP ) #cuantos cuadros hay

    if evocada
        retms=5.0 #retraso en milisec
        latms=4.0 #latencia en milisec
        retraso=round(Int, retms * frecuencia)
        lat=round(Int, latms * frecuencia)
        desde=retraso+lat
        hasta=300
    else
        retms=0
        latms=0
        retraso=0
        lat=0
        desde=1
        hasta=nmax
    end
    pesomin=5
    longmin=3
    # With the above parameters set, let us check the time for all Source Trajectories.
    CatenarioPositivo=encuentraTrayectorias( CMP , longmin , pesomin , desde , hasta );
    CatenarioNegativo=encuentraTrayectorias( CMN , longmin , pesomin , desde , hasta );
     
    return CatenarioPositivo , CatenarioNegativo
            
end

function encuentraTrayectorias(Datos, mincadena=20, mingordo=2.0, desde=1,hasta=20)

    toleradist=16*sqrt(2)
    #toldifgordis=0.33
    tau=1
    t=1
    j=1
    Catenario=Dict{Integer, Array{Any}}()
    Cadena=[0 0 0 0]
    tnum=1
    CopiaMegaArray=deepcopy(Datos);
    NumFrames=length(Datos)
    FakeNumFrames=NumFrames
    while t <= FakeNumFrames-1 
        tau=t
        @label arrrrh
            if(CopiaMegaArray[tau]==[])

                jmax,nada=0,0
            else
         jmax,nada= size(CopiaMegaArray[tau])
            end
        while j <=jmax && tau<FakeNumFrames
                if abs(CopiaMegaArray[tau][j,3]) > mingordo
                Eslabon=[transpose(CopiaMegaArray[tau][j,:]) tau]
                Cadena=vcat(Cadena, Eslabon)
             #   println("Papa t: ", t, "  tau: ", tau, " y  j: ",j )
                mindist=2
                kasterisco=1
                    if CopiaMegaArray[tau+1]==[]
                        kmax,nada=0,0
                    else
                    kmax, nada= size(CopiaMegaArray[tau+1])
                    end
                    huboalgo=false
            #    kmax=5
                for k=1:kmax
                    EslabonTentativo=CopiaMegaArray[tau+1][k,:]
                #    println(EslabonTentativo)
                        if abs(EslabonTentativo[3])>mingordo
                        dist=dist2D(Eslabon,EslabonTentativo)                  
                        if dist<mindist
                            mindist=dist
                            kasterisco=k
                           # println(kasterisco, "=k*", k, "=k")
                            huboalgo=true
                        end
                    end
                end    
                if huboalgo && mindist<toleradist
                    #quitamos el anterior
                    CopiaMegaArray[tau][j,3]=0.0000 
                   # println(mindist," ", t, " ", tau+1 ," ", kasterisco )
                    if tau+1<FakeNumFrames
                        tau+=1
                        j=kasterisco
          #              println("Pepe t: ", t, "  tau: ", tau, " y  j: ",j )
                        @goto arrrrh
                    else
                        Eslabon=[transpose(CopiaMegaArray[tau+1][kasterisco,:]) tau+1]
                        Cadena=vcat(Cadena, Eslabon)
          #              println("Pipi t: ", t, "  t: ", t, " y  j: ",j )
                        j+=1
                        tau=t
                        if size(Cadena)[1]>mincadena
                            #push!(Catenario, Cadena[2:end,:])
                            Catenario[tnum]=Cadena[2:end,:]
                            tnum+=1
                        end
                        Cadena=[0 0 0 0]
                        @goto arrrrh
                    end
                else
                    if size(Cadena)[1]>mincadena
                        # veamos si funciona  mejor como dict 
                            #push!(Catenario, Cadena[2:end,:])
                            Catenario[tnum]=Cadena[2:end,:]
                            tnum+=1
                    end
                    Cadena=[0 0 0 0]
                    j+=1
                    tau=t
                    @goto arrrrh
                end
            end #cierra sobre el if de  la masa 
            j+=1                    
            tau=t
        end
        @label urrr
        j=1
        t+=1
        tau=t
        Cadena=[0 0 0 0]
    end 
    return Catenario
end



end