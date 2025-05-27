module DelegatorTraits

export Interface
export DelegatorTrait, DontDelegate, DelegateToField, delegator
export ImplementorTrait, Implements, NotImplements
export Effect, checkeffect, handle!
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

"""
    Effect

Abstract type for effects.
"""
abstract type Effect end

# TODO maybe we should declare a `checkeffect_rule` function to be implemented by users?
# this way we can make sure that the effect is checked all the way down the interface levels
# and not rely on the user calling `checkeffect` on the delegator if they implement it at some level
"""
    checkeffect(x, effect::Effect)

Check if `x` can [`handle!`](@ref) the `effect` and if it's valid for `x`.
"""
function checkeffect end

"""
    handle!(x, effect::Effect)

Handle the `effect` on `x`.
"""
function handle! end

fallback(f) = @debug "Falling back to default method" f

end # module DelegatorTraits
