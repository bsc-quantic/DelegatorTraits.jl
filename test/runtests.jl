using Test
using DelegatorTraits

@testset "Unit" begin
    struct MyInterface1 <: Interface end
    DelegatorTraits.ImplementorTrait(::MyInterface1, ::Integer) = Implements()

    @test ImplementorTrait(MyInterface1(), 1) === Implements()
    @test ImplementorTrait(MyInterface1(), 1.0) === NotImplements()

    struct FakeInteger <: Integer end
    @test ImplementorTrait(MyInterface1(), FakeInteger()) === Implements()

    struct DelegatedInteger
        x::Integer
    end
    DelegatorTraits.DelegatorTrait(::MyInterface1, ::DelegatedInteger) = DelegateToField{:x}()

    @test ImplementorTrait(MyInterface1(), DelegatedInteger(1)) === Implements()

    struct DelegatedTwiceInteger
        y::DelegatedInteger
    end
    DelegatorTraits.DelegatorTrait(::MyInterface1, ::DelegatedTwiceInteger) = DelegateToField{:y}()

    @test ImplementorTrait(MyInterface1(), DelegatedTwiceInteger(DelegatedInteger(1))) === Implements()
end
