module DelegatorTraits

export Interface
export DelegatorTrait, DontDelegate, DelegateToField, delegator
export ImplementorTrait, Implements, NotImplements
export fallback

"""
    Interface

Abstract type for interfaces. New interfaces should subtype this type.
"""
abstract type Interface end

"""
    DelegatorTrait

Abstract type for delegator traits. New delegator traits should subtype this type.
Currently, there are two delegator traits:

  - `DontDelegate`: the interface does not delegate to any field.
  - `DelegateToField{T}`: the interface delegates to field `T` of the object..
"""
abstract type DelegatorTrait end
struct DontDelegate <: DelegatorTrait end
struct DelegateToField{T} <: DelegatorTrait end

"""
DelegatorTrait(interface, x)

Get the delegator trait of object `x` for `interface`.
Defaults to `DontDelegate()`; i.e. assume responsability for implementing the interface.
"""
DelegatorTrait(interface, x) = DontDelegate()

"""
    delegator(interface, x)

Get the delegator responsible for the `interface` on behalf of object `x`.
"""
delegator(interface, x) = delegator(interface, x, DelegatorTrait(interface, x))
delegator(interface, x, ::DontDelegate) = throw(ArgumentError("Cannot delegate to $interface"))
delegator(interface, x, ::DelegateToField{P}) where {P} = getproperty(x, P)

"""
    ImplementorTrait

Abstract type for implementor traits. It has two traits:

  - `Implements`: the interface is implemented by the object.
  - `NotImplements`: the interface is not implemented by the object.
"""
abstract type ImplementorTrait end
struct Implements <: ImplementorTrait end
struct NotImplements <: ImplementorTrait end

# recurse check to delegator
"""
    ImplementorTrait(interface, x)

Check if `x` implements the `interface`. If it does, return `Implements()`, otherwise return `NotImplements()`.

!!! note

    Implementors of an interface should declare that they implement an interface by adding the following code:

    ```julia
    ImplementorTrait(::MyInterface, ::MyImplementor) = Implements()
    ```
"""
ImplementorTrait(interface, x) = ImplementorTrait(interface, x, DelegatorTrait(interface, x))
ImplementorTrait(interface, x, ::DontDelegate) = NotImplements()
ImplementorTrait(interface, x, ::DelegateToField{P}) where {P} = ImplementorTrait(interface, delegator(interface, x))

fallback(f) = @debug "Falling back to default method" f

include("Effects.jl")

end # module DelegatorTraits
