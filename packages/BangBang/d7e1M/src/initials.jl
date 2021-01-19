InitialValues.@def push!! [x]

# # Custom definition for `monoid!!(_, Init(monoid!!))`
#
# Using the default approach `InitialValues.@def_monoid monoid!!` was
# problematic because defining `monoid!!(::CustomType, x)` introduced
# method ambiguities.  It could be solved semi-automatically by
# `@disambiguate append!! CustomType` but it is very ugly and very
# problematic for the extensibility of the method.
#
# Furthermore, the definition
#
#     append!!(::InitAppend!!, src) = src
#
# that is generated by `@def_monoid` is not appropriate if `src`
# should be consumed by the time `append!!` is called (e.g.,
# https://discourse.julialang.org/t/38845/3).  This is mostly the case
# since the returned value of `monoid!!(init, src)` would be used as
# the first argument (i.e., it would be mutated) in the "next
# iteration" in reduction code idioms.  That is to say, `monoid!!`
# should not assume the ownership of the second argument.
#
# The method ambiguity problem is solved by introducing a "dispatch
# pipeline"; i.e., a `CustomType` implementer can overload
# `__monoid!!__` instead of `monoid!!`.
#
# The memory ownership problem is solved by defining InitialValues.jl
# interface manually.  For example, `append!!(::InitAppend!!, src)`
# now calls `copymutable(src)`.
#
# ## Alternative approach
#
# For `append!!`, an alternative approach considered is to create a
# custom `EmptyCollection` type that behaves like "an" identity
# element of `append!!`.  This may be possible by allowing
# `InitialValues.Init(::typeof(monoid!!))` overload.  This approach
# has some nice properties:
#
# * No need to define `append!!(::Any, ::InitType)` as it would work
#   via the default implementation of `append!!` based on iterator.
#   (The flip-side is that a bug could be hidden if the init object is
#   fed to other functions like `collect`. But this is not a serious
#   problem.)
#
# * By using the trait mechanism and defining `NoBang.append`,
#   `append!!` would behave as expected without any "surface"
#   dispatches.
#
# A *major downside* of this approach is that the fold code does not
# have a canonical way to check if `monoid!!` is ever called.  If
# overloading `InitialValues.Init` were supported, the fold
# implementers cannot simply call `acc isa InitialValue` to check if
# `acc = monoid!!(acc, x)` was called at least once.

const InitAppend!! = InitialValues.GenericInitialValue{typeof(append!!)}
append!!(::InitAppend!!, src) = copyappendable(src)
append!!(dest, ::InitAppend!!) = dest
append!!(dest::InitAppend!!, ::InitAppend!!) = dest
InitialValues.hasinitialvalue(::Type{typeof(append!!)}) = true

copyappendable(src) = Base.copymutable(src)

const InitMergeWith!!{F} = InitialValues.GenericInitialValue{MergeWith!!{F}}
(f::MergeWith!!{F})(dest::InitMergeWith!!{F}, src) where {F} = copymergeable(src)
(f::MergeWith!!{F})(dest, ::InitMergeWith!!{F}) where {F} = dest
(f::MergeWith!!{F})(dest::InitMergeWith!!{F}, src::InitMergeWith!!{F}) where {F} = dest
InitialValues.hasinitialvalue(::Type{MergeWith!!{F}}) where {F} = true

const InitMerge!! = InitialValues.GenericInitialValue{typeof(merge!!)}
merge!!(dest::InitMerge!!, src) = copymergeable(src)
merge!!(dest, ::InitMerge!!) = dest
merge!!(dest::InitMerge!!, src::InitMerge!!) = dest
merge!!(::Base.Callable, dest::InitMerge!!) = dest  # disambiguation
InitialValues.hasinitialvalue(::Type{typeof(merge!!)}) = true

copymergeable(src) = Dict(src)
copymergeable(src::NamedTuple) = src

const InitUnion!! = InitialValues.GenericInitialValue{typeof(union!!)}
union!!(dest::InitUnion!!, src) = copyunionable(src)
union!!(dest, ::InitUnion!!) = dest
union!!(dest::InitUnion!!, src::InitUnion!!) = dest
InitialValues.hasinitialvalue(::Type{typeof(union!!)}) = true

copyunionable(src::AbstractVector) = Base.copymutable(src)
copyunionable(src) = Set(src)