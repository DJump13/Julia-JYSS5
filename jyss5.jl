using Match
using Test

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
            _ => error("JYSS: IF DOES NOT EVALUATE TO BOOLEAN")
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
                                    _ => false
                                end)
                        end
                    elseif length(args) == 1
                        @match interp(args[1], env) begin
                            PrimopV(:error) => error("JYSS: USER ERROR")
                            _ => error("JYSS: PRIMOP NEEDS 2 ARGUMENTS")
                        end
                    else
                        error("JYSS: PRIMOP NEEDS 2 ARGUMENTS")
                    end
                ClosV(cargs, cbody, cenv) => interp(cbody, addToEnv(cenv, cargs, interpList(args, env)))
                _ => error("JYSS: INVALID SYNTAX")
            end
        end
    end
end

function interpList(vals::Array{ExprC}, env::Dict{Symbol,Value})::Array{Value}
    map(v -> interp(v, env), vals)
end

function addToEnv(env::Dict{Symbol,Value}, args::Array{Symbol}, vals::Array{Value})::Dict{Symbol,Value}
    if length(args) == length(vals)
        merge(env, Dict(zip(args, vals)))
    else
        error("JYSS: WRONG NUMBER OF ARGUMENTS")
    end
end

@test interp(IdC(:+), makeEnv) == PrimopV(:+)
@test interp(NumC(5), makeEnv) == NumV(5)
@test interp(StrC("Hello"), makeEnv) == StrV("Hello")

@test interpList([IdC(:+), NumC(5)], makeEnv) == [PrimopV(:+), NumV(5)]

@test interp(IfC(AppC(IdC(:<=), [NumC(5), NumC(4)]), NumC(1), NumC(-1)), makeEnv) == NumV(-1)
@test interp(AppC(IdC(:+), [AppC(IdC(:-), [NumC(10), NumC(7)]), NumC(5)]), makeEnv) == NumV(8)
@test interp(AppC(IdC(:*), [AppC(IdC(:/), [NumC(10), NumC(2)]), NumC(5)]), makeEnv) == NumV(25.0)
@test interp(IfC(AppC(IdC(:equal), [StrC("BRUH"), StrC("BRUH")]), NumC(1), NumC(-1)), makeEnv) == NumV(1)

#below test is equivalent to running '{{proc {x y} go {+ x y}} {{+ 9 14} 98}}
@test interp(AppC(LamC([:x, :y], AppC(IdC(:+), [IdC(:x), IdC(:y)])),
        [AppC(IdC(:+), [NumC(9), NumC(14)]), NumC(98)]), makeEnv) == NumV(121)
#below test is equivalent to running '{{proc {a b} go {- a b}} {{* 2 2} 3}}
@test interp(AppC(LamC([:a, :b], AppC(IdC(:-), [IdC(:a), IdC(:b)])),
        [AppC(IdC(:*), [NumC(2), NumC(2)]), NumC(3)]), makeEnv) == NumV(1)

@test_throws "JYSS: PRIMOP NEEDS 2 ARGUMENTS" interp(AppC(IdC(:+), [NumC(5)]), makeEnv)
@test_throws "JYSS: IF DOES NOT EVALUATE TO BOOLEAN" interp(IfC(NumC(1), NumC(2), NumC(3)), makeEnv)



