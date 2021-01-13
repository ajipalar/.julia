##############################################################################
##
## Functions related to the interface with PrettyTables.jl.
##
##############################################################################

# Default DataFrames highlighter for text backend.
#
# This highlighter changes the text color to gray in cells with `nothing`,
# `missing`, `#undef`, and types related to DataFrames.jl.
function _pretty_tables_highlighter_func(data, i::Integer, j::Integer)
    try
        cell = data[i, j]
        return ismissing(cell) ||
            cell === nothing ||
            cell isa Union{AbstractDataFrame, GroupedDataFrame,
                           DataFrameRow, DataFrameRows,
                           DataFrameColumns}
    catch e
        if isa(e, UndefRefError)
            return true
        else
            rethrow(e)
        end
    end
end

const _PRETTY_TABLES_HIGHLIGHTER = Highlighter(_pretty_tables_highlighter_func,
                                               Crayon(foreground = :dark_gray))

# Default DataFrames formatter for text backend.
#
# This formatter changes how the following types are presented when rendering
# the data frame:
#     - missing;
#     - nothing;
#     - Cells with types related to DataFrames.jl.

function _pretty_tables_general_formatter(v, i::Integer, j::Integer)
    if typeof(v) <: Union{AbstractDataFrame, GroupedDataFrame, DataFrameRow,
                          DataFrameRows, DataFrameColumns}

        # Here, we must not use `print` or `show`. Otherwise, we will call
        # `_pretty_table` to render the current table leading to a stack
        # overflow.
        return sprint(summary, v)
    elseif ismissing(v)
        return "missing"
    elseif v === nothing
        return ""
    else
        return v
    end
end

# Formatter to align the floating points as in Julia array printing.
#
# - `float_cols` contains the IDs of the columns that must be formatted.
# - `indices` is a vector of vectors containing the indices of each elements
#   in the data frame.
# - `padding` is a vector of vectors containing the padding of each element for
#   each row.
# - `compact_printing` must be a boolean indicating if we should enable the
#   `:compact` option of `io` when converting the number to string.

function _pretty_tables_float_formatter(v, i::Integer, j::Integer,
                                        float_cols::Vector{Int},
                                        align_col::Vector{Int},
                                        compact_printing::Bool)
    isempty(float_cols) && return v

    # We apply this formatting only to the columns that contains only floats.
    ind_col = findfirst(==(j), float_cols)

    if ind_col !== nothing
        align_col_i = align_col[ind_col]

        # Convert the value to text.
        str = sprint(print, v, context = :compact => compact_printing)

        if v == "missing"
            pad = align_col_i - 8
        else
            # We want to align everything at '.'.
            id_dp = findfirst('.', str)

            # Compute the require padding to align the cell.
            #
            # If a decimal point is not found, then assume that the
            # entire text should be aligned before the alignment column. This
            # can happen with a custom `AbstractFloat` type.
            pad = id_dp !== nothing ? align_col_i - id_dp :
                                      align_col_i - (textwidth(str) + 1)
        end

        # Pad cannot be negative.
        # NOTE: This is just a failsafe, `pad` will be negative only if we have
        # a bug. However, in this case, we can avoid an error when printing.
        pad < 0 && (pad = 0)

        return " "^pad * str
    end

    # The formatter is applied to all tables' cells. Hence, we must return the
    # input value `v` unchanged if this cell is not part of a column that has
    # floating point numbers.
    return v
end
