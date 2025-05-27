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
