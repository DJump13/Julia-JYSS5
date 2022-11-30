using Match
using Test
#Pkg.add("Match")

abstract type ExprC end
struct NumC <: ExprC
    n::Real
end
struct IdC <: ExprC
    s::Symbol
end
struct StrC <: ExprC
    s::String
end
struct AppC <: ExprC
    body::ExprC
    args::Array{ExprC}
end
struct IfC <: ExprC
    c::ExprC
    t::ExprC
    e::ExprC
end
struct LamC <: ExprC
    args::Array{Symbol}
    body::ExprC
end

abstract type Value end
struct NumV <: Value
    n::Real
end
struct BoolV <: Value
    b::Bool
end
struct StrV <: Value
    s::String
end
struct ClosV <: Value
    args::Array{Symbol}
    body::ExprC
    env::Dict{Symbol,Value}
end
struct PrimopV <: Value
    s::Symbol
end

makeEnv = Dict(
    :True => BoolV(true),
    :False => BoolV(false),
    :+ => PrimopV(:+),
    :- => PrimopV(:-),
    :* => PrimopV(:*),
    :/ => PrimopV(:/),
    :<= => PrimopV(:<=),
    :equal => PrimopV(:equal),
    :error => PrimopV(:error))

function interp(a::ExprC, env::Dict{Symbol,Value})::Value
    @match a begin
        NumC(n) => NumV(n)
        StrC(s) => StrV(s)
        IdC(s) => env[s]
        IfC(c, t, e) => @match interp(c, env) begin
            BoolV(b) =>
                if b
                    interp(t, env)
                else
                    interp(e, env)
                end
        end
        LamC(args, body) => ClosV(args, body, env)
        AppC(body, args) => @match body begin
            IdC(:error) => error("JYSS: USER ERROR")
            _ => @match interp(body, env) begin
                PrimopV(s) =>
                    if length(args) == 2
                        @match s begin
                            :+ => NumV(interp(args[1], env).n + interp(args[2], env).n)
                            :- => NumV(interp(args[1], env).n - interp(args[2], env).n)
                            :* => NumV(interp(args[1], env).n * interp(args[2], env).n)
                            :/ => NumV(interp(args[1], env).n / interp(args[2], env).n)
                            :<= => BoolV(interp(args[1], env).n <= interp(args[2], env).n)
                            :equal => BoolV(
                                @match interp(args[1], env) begin
                                    NumV(n) => (n == interp(args[2], env).n)
                                    BoolV(b) => (b == interp(args[2], env).b)
                                    StrV(s) => (s == interp(args[2], env).s)
                                end)
                        end
                    end
            end
        end
    end
end

@test interp(IdC(:+), makeEnv) == PrimopV(:+)
@test interp(IfC(AppC(IdC(:<=), [NumC(5), NumC(4)]), NumC(1), NumC(-1)), makeEnv) == NumV(-1)
@test interp(AppC(IdC(:+), [AppC(IdC(:-), [NumC(10), NumC(7)]), NumC(5)]), makeEnv) == NumV(8)
@test interp(AppC(IdC(:*), [AppC(IdC(:/), [NumC(10), NumC(2)]), NumC(5)]), makeEnv) == NumV(25.0)
#interp(AppC(IdC(:error), [NumC(5), NumC(5)]), makeEnv)



