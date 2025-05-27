# DelegatorTraits.jl

This package is a minimal package that tries to formalize _inheritance through composition_ via the "delegator pattern" (or something akin to it).
Unlike other trait / interfaces packages in Julia, it avoids (a) using macros that can preven customization, and (b) doing _too much_.

!!! note
    By "interface" we mean a collection of functions (methods could also be part of it but check out that they are not the same), while by "trait" we mean the behavior taken by a type on a given scenario.
    The names or exact semantics of these concepts can vary between languages, but we subscript to these definitions.

As an example, in Base Julia there is the ["Iteration" interface](https://docs.julialang.org/en/v1/manual/interfaces/#man-interface-iteration) which has the [`Base.IteratorSize`](https://docs.julialang.org/en/v1/base/collections/#Base.IteratorSize) and [`Base.IteratorEltype`](https://docs.julialang.org/en/v1/base/collections/#Base.IteratorEltype) trait querying functions.

- [`Base.IteratorSize`](https://docs.julialang.org/en/v1/base/collections/#Base.IteratorSize) has the traits `SizeUnknown`, `HasLength`, `HasShape{N}` and `IsInfinite`.
- [`Base.IteratorEltype`](https://docs.julialang.org/en/v1/base/collections/#Base.IteratorEltype) has the traits `EltypeUnknown` and `HasEltype`.

In some sense, a "trait collection" is like a enumeration where each element (i.e. trait) is a type. Thanks to Julia's multiple-dispatch, you can use those elements / traits for selecting different implementations and that's how the Holy Traits mechanism works 🎉.

One problem I was finding often is that if I want to reuse components that implement some interfaces and incrementally construct over them, I was finding a lot of problems to ...

DelegatorTraits.jl is not reinventing the wheel, nor proposing anything crazy.

DelegatorTraits.jl makes interfaces a real object through the `Interface` abstract type. Following the "Iteration" interface, we could concretize it with the following line of code:

```julia
struct Iterator <: Interface end
```

Note that unlike other interface proposals, DelegatorTraits.jl doesn't try to declare a method inside that interface.
Instead, functions ask the object if it delegates the object on the case that a method has not yet been implemented for such object, just like with Holy traits (but the trait is the `DelegatorTrait`).

Delegation will recursively unwrap the objects until it finds the object that implements it.
In the case that there is no implementor for an interface, authors can decide whether to return a default value or throw a `MethodError`.

```julia
MyIteratorSize(x) = MyIteratorSize(x, DelegatorTrait(Iterator(), x))
MyIteratorSize(x, ::DontDelegate) = Base.SizeUnknown() # or throw(MethodError(MyIteratorSize, (x,)))
MyIteratorSize(x, ::DelegateToField) = MyIteratorSize(delegator(Iterator(), x))
```

These interfaces are easily extendable to external types:

```julia
MyIteratorSize(::Vector) = Base.HasShape{1}()
```

To declare that a type delegates its implementation of an interface to some field, you just need to define `DelegatorTrait` to return a `DelegateToField{:field_name}()` for the given `Interface` and type combination:

```julia
julia> struct MyCollection
            my_vec::Vector{Any}
        end

julia> DelegatorTraits.DelegatorTrait(::Iterator, ::MyCollection) = DelegateToField{:my_vec}()

julia> my_collection = MyCollection([1, 2, 3])
MyCollection(Any[1, 2, 3])

julia> MyIteratorSize(my_collection)
Base.HasShape{1}()
```

Note that if you can override any function (while leaving the rest to delegation) by simply writing a method for your type. This would similar to overriding a method in traditional OOP languages.

```julia
julia> function MyIteratorSize(::MyCollection)
            @show "Overrided `MyIteratorSize` for `MyCollection`"
            return Base.SizeUnknown()
        end
MyIteratorSize (generic function with 5 methods)

julia> MyIteratorSize(my_collection)
[ Info: Overrided `MyIteratorSize` for `MyCollection`
Base.SizeUnknown()
```

Also, because this information about traits is known statically, delegation is type-stable and incurs in no runtime overhead!

```julia
julia> @code_typed MyIteratorSize(my_collection)
CodeInfo(
1 ─     return $(QuoteNode(Base.HasShape{1}()))
) => Base.HasShape{1}
```

## Handling mutation with Effects

!!! warn

    Effects are a experimental feature not yet ready for production. Here is a little description of the feature, but you shouldn't yet use it because the API can break.

One of the problems of delegation is that mutation can break "mappings" on higher delegated levels.
For example, given a `Network` or graph, what if there we have a network / graph whose vertices have _weights_?

```julia
struct VertexWeightedNetwork
    network::SomeImplementationOfNetwork
    weights::Dict{Vertex,Float64}
end

DelegatorTraits.DelegatorTrait(::Network, ::VertexWeightedNetwork) = DelegateToField{:network}()
```

Calling `rmedge!`, from the `Network` interface, would effectively remove the edge, but the `weights` wouldn't be notified,
storing an edge that no longers exists.
The way this is usually handled in Julia is by manually implementing `rmedge!` for `VertexWeightedNetwork`.

```julia
function Networks.rmedge!(wn::VertexWeightedNetwork, edge)
    # call the delegator
    rmedge!(wn.network, edge)

    # fix the mapping
    delete!(wn.weights, edge)
end
```

This can lead to several problems:

1. As the "inheritance" becomes more and more nested, the implementation or manual delegation becomes more cumbersome. In my experience, Julia is not a language that handles well deeply nested structures (from the software development point of view).
2. Some mapping updates (i.e. handling the effect) require to be performed before the actual mutation (i.e. the _inner_ method) while others require it to be performed before.
3. Sometimes you need to run the checks at all levels before performing any mutation (e.g. performing a mutation and then checking in another level that you shouldn't have done it leaves the object in a non-coherent state).

Instead, we can try encapsulate the mutation within an `Effect` object and propagate it to all the levels to...

1. Check that all the levels agree that the mutation can be performed
2. Perform the mutation
3. Update any mapping the mutation could have broken

For example, an hypotetical `addvertex!` method could be implemented like this:

```julia
function addvertex!(graph, v)
    checkeffect(graph, AddVertexEffect(v)) # step 1
    addvertex_inner!(graph, v) # step 2
    handle!(graph, AddVertexEffect(v)) # step 3
    return graph
end
```

```julia
checkeffect(graph, e::AddVertexEffect) = checkeffect(graph, e, DelegatorTrait(Network(), graph))
checkeffect(graph, e::AddVertexEffect, ::DelegateTo) = checkeffect(delegator(Network(), graph), e)
function checkeffect(graph, e::AddVertexEffect, ::DontDelegate)
    hasvertex(graph, e.vertex) && throw(ArgumentError("Vertex $(e.vertex) already exists in network"))
end

# by default, do nothing because no extra mapping should be defined at this level
handle!(graph, e::AddVertexEffect) = handle!(graph, e, DelegatorTrait(Network(), graph))
handle!(graph, e::AddVertexEffect, ::DelegateTo) = handle!(delegator(Network(), graph), e)
handle!(graph, e::AddVertexEffect, ::DontDelegate) = nothing
```

By defining a `checkeffect` or `handle!` on your type, you can intercept the `Effect` without messing around and no matter the nesting level.
For example, With a single line of code, we can forbid deleting edges that have a weight assigned to it:

```julia
function DelegatorTraits.checkeffect(wn::VertexWeightedNetwork, e::RemoveVertexEffect)
    # level of VertexWeightedNetwork
    haskey(wn.weights, e.edge) && throw(ArgumentError("cannot remove edge $(e.edge) because it has an assigned weight"))

    # propagate to Network delegator
    checkeffect(wn.network, e)
end
```

or if instead we want to be more permisive and fix the mapping by removing the weight on edge removal...

```julia
DelegatorTraits.checkeffect(::VertexWeightedNetwork, ::RemoveEdgeEffect) = nothing
DelegatorTraits.handle!(wn::VertexWeightedNetwork, e::RemoveEdgeEffect) = delete!(wn, e.edge)
```

We could also assign a default weight when introducing an edge:

```julia
DelegatorTraits.checkeffect(::VertexWeightedNetwork, ::AddEdge) = nothing
DelegatorTraits.handle!(wn::VertexWeightedNetwork, e::AddEdge) = wn.weights[e.edge] = 0.0
```

## Do I need this package?

The package is so minimal (this README is way longer than the package) that you may no need it.

It's mostly a design philosophy that just tries to formalize what an interface is and how we can correctly do _inheritance via composition_.

You may not even need a delegation mechanism, but using it leads to clean code that scales and is less error-prone (personal experience).
And if you find yourself repeating this pattern on several packages, it may be good idea to use this library to unify delegation.

## Open questions

- What about `Interface`s that require other `Interface`s to be implemented?
- What about functions that require multiple `Interface`s to be implemented? How should we delegate? Or we shouldn't?

## Examples

Some libraries already using DelegatorTraits.jl are:

- [Networks.jl](https://github.com/bsc-quantic/Networks.jl)
- [TenetCore.jl](https://github.com/bsc-quantic/TenetCore.jl)
- [Tangles.jl](https://github.com/bsc-quantic/Tangles.jl)
