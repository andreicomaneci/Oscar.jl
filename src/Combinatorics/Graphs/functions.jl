import Oscar: Polyhedron, Polymake, pm_object
import Oscar.Polymake: Directed, Undirected

function pm_object(G::Graph{T}) where {T <: Union{Directed, Undirected}}
    return G.pm_graph
end

function pm_object(PT::PhylogeneticTree)
  return PT.pm_ptree
end

################################################################################
################################################################################
##  Constructing and modifying
################################################################################
################################################################################

@doc raw"""
    Graph{T}(nverts::Int64) where {T <: Union{Directed, Undirected}}

Construct a graph on `nverts` vertices and no edges. `T` indicates whether the
graph should be `Directed` or `Undirected`.

# Examples
Make a directed graph with 5 vertices and print the number of nodes and edges.
```jldoctest
julia> g = Graph{Directed}(5);

julia> number_of_vertices(g)
5

julia> number_of_edges(g)
0
```
"""
function Graph{T}(nverts::Int64) where {T <: Union{Directed, Undirected}}
    pmg = Polymake.Graph{T}(nverts)
    return Graph{T}(pmg)
end

@doc raw"""
    graph_from_adjacency_matrix(::Type{T}, G) where {T <:Union{Directed, Undirected}}

Return the graph with adjacency matrix `G`.

This means that the nodes ``i, j`` are connected by an edge
if and only if ``G_{i,j}`` is one.
In the undirected case, it is assumed that ``i > j`` i.e. the upper triangular
part of ``G`` is ignored.

# Examples
```jldoctest
julia> G = ZZ[0 0; 1 0]
[0   0]
[1   0]

julia> graph_from_adjacency_matrix(Directed, G)
Directed graph with 2 nodes and the following edges:
(2, 1)

julia> graph_from_adjacency_matrix(Undirected, G)
Undirected graph with 2 nodes and the following edges:
(2, 1)

```
"""
graph_from_adjacency_matrix(::Type, G::Union{MatElem, Matrix})

function graph_from_adjacency_matrix(::Type{T}, G::Union{MatElem, Matrix}) where {T <: Union{Directed, Undirected}}
  n = nrows(G)
  @req nrows(G)==ncols(G) "not a square matrix"
  g = Graph{T}(n)
  for i in 1:n
    for j in 1:(T==Undirected ? i-1 : n)
      if isone(G[i,j])
        add_edge!(g, i, j)
      else
        iszero(G[i,j]) || error("not an adjacency matrix")
      end
    end
  end
  return g
end


_has_node(G::Graph, node::Int64) = 0 < node <= nvertices(G)

@doc raw"""
    add_edge!(g::Graph{T}, s::Int64, t::Int64) where {T <: Union{Directed, Undirected}}

Add edge `(s,t)` to the graph `g`.
Return `true` if a new edge `(s,t)` was added, `false` otherwise.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> add_edge!(g, 1, 2)
true

julia> add_edge!(g, 1, 2)
false

julia> number_of_edges(g)
1
```
"""
function add_edge!(g::Graph{T}, source::Int64, target::Int64) where {T <: Union{Directed, Undirected}}
  _has_node(g, source) && _has_node(g, target) || return false
  old_nedges = nedges(g)
  Polymake._add_edge(pm_object(g), source-1, target-1)
  return nedges(g) == old_nedges + 1
end


@doc raw"""
    rem_edge!(g::Graph{T}, s::Int64, t::Int64) where {T <: Union{Directed, Undirected}}

Remove edge `(s,t)` from the graph `g`.
Return `true` if there was an edge from `s` to `t` and it got removed, `false`
otherwise.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> add_edge!(g, 1, 2)
true

julia> number_of_edges(g)
1

julia> rem_edge!(g, 1, 2)
true

julia> number_of_edges(g)
0
```
"""
function rem_edge!(g::Graph{T}, s::Int64, t::Int64) where {T <: Union{Directed, Undirected}}
  has_edge(g, s, t) || return false
  old_nedges = nedges(g)
  Polymake._rem_edge(pm_object(g), s-1, t-1)
  return nedges(g) == old_nedges - 1
end


@doc raw"""
    add_vertex!(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Add a vertex to the graph `g`. Return `true` if there a new vertex was actually
added.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> number_of_vertices(g)
2

julia> add_vertex!(g)
true

julia> number_of_vertices(g)
3
```
"""
function add_vertex!(g::Graph{T}) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g)
    old_nvertices = nvertices(g)
    Polymake._add_vertex(pmg)
    return nvertices(g) - 1 == old_nvertices
end


@doc raw"""
    rem_vertex!(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}

Remove the vertex `v` from the graph `g`. Return `true` if node `v` existed and
was actually removed, `false` otherwise.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> number_of_vertices(g)
2

julia> rem_vertex!(g, 1)
true

julia> number_of_vertices(g)
1
```
"""
function rem_vertex!(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}
  _has_node(g, v) || return false
  pmg = pm_object(g)
  old_nvertices = nvertices(g)
  result = Polymake._rem_vertex(pmg, v-1)
  Polymake._squeeze(pmg)
  return nvertices(g) + 1 == old_nvertices
end


@doc raw"""
    add_vertices!(g::Graph{T}, n::Int64) where {T <: Union{Directed, Undirected}}

Add a `n` new vertices to the graph `g`. Return the number of vertices that
were actually added to the graph `g`.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> number_of_vertices(g)
2

julia> add_vertices!(g, 5);

julia> number_of_vertices(g)
7
```
"""
function add_vertices!(g::Graph{T}, n::Int64) where {T <: Union{Directed, Undirected}}
  return count(_->add_vertex!(g), 1:n)
end


################################################################################
################################################################################
##  Edges
################################################################################
################################################################################
struct Edge
    source::Int64
    target::Int64
end


@doc raw"""
    src(e::Edge)

Return the source of an edge.

# Examples
```jldoctest
julia> g = complete_graph(2);

julia> E = collect(edges(g));

julia> e = E[1]
Edge(2, 1)

julia> src(e)
2
```
"""
function src(e::Edge)
    return e.source
end


@doc raw"""
    dst(e::Edge)

Return the destination of an edge.

# Examples
```jldoctest
julia> g = complete_graph(2);

julia> E = collect(edges(g));

julia> e = E[1]
Edge(2, 1)

julia> dst(e)
1
```
"""
function dst(e::Edge)
    return e.target
end

Vector{Int}(e::Edge) = [src(e), dst(e)]

Base.isless(a::Edge, b::Edge) = Base.isless(Vector{Int}(a), Vector{Int}(b))


@doc raw"""
    reverse(e::Edge)

Return the edge in the opposite direction of the edge `e`.

# Examples
```jldoctest
julia> g = complete_graph(2);

julia> E = collect(edges(g));

julia> e = E[1]
Edge(2, 1)

julia> reverse(e)
Edge(1, 2)
```
"""
function reverse(e::Edge)
    return Edge(dst(e), src(e))
end


struct EdgeIterator
    pm_itr::Polymake.GraphEdgeIterator{T} where {T <: Union{Directed, Undirected}}
    l::Int64
end
Base.length(eitr::EdgeIterator) = eitr.l
Base.eltype(::Type{EdgeIterator}) = Edge

function Base.iterate(eitr::EdgeIterator, index = 1)
    if index > eitr.l
        return nothing
    else
        e = Polymake.get_element(eitr.pm_itr)
        s = Polymake.first(e)
        t = Polymake.last(e)
        edge = Edge(s+1, t+1)
        Polymake.increment(eitr.pm_itr)
        return (edge, index+1)
    end
end


################################################################################
################################################################################
##  Accessing properties
################################################################################
################################################################################
@doc raw"""
    number_of_vertices(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Return the number of vertices of a graph.

# Examples
The edge graph of the cube has eight vertices, just like the cube itself.
```jldoctest
julia> c = cube(3);

julia> g = edgegraph(c);

julia> number_of_vertices(g)
8
```
"""
function number_of_vertices(g::Graph{T}) where {T <: Union{Directed, Undirected}}
    return Polymake.nv(pm_object(g))
end

@doc raw"""
    number_of_edges(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Return the number of edges of a graph.

# Examples
The edge graph of the cube has 12 edges just like the cube itself.
```jldoctest
julia> c = cube(3);

julia> g = edgegraph(c);

julia> number_of_edges(g)
12
```
"""
function number_of_edges(g::Graph{T}) where {T <: Union{Directed, Undirected}}
    return Polymake.ne(pm_object(g))
end

@doc raw"""
    edges(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Return an iterator over the edges of the graph `g`.

# Examples
A triangle has three edges.
```jldoctest
julia> triangle = simplex(2);

julia> g = edgegraph(triangle);

julia> collect(edges(g))
3-element Vector{Edge}:
 Edge(2, 1)
 Edge(3, 1)
 Edge(3, 2)
```
"""
function edges(g::Graph{T}) where {T <: Union{Directed, Undirected}}
    return EdgeIterator(Polymake.edgeiterator(pm_object(g)), number_of_edges(g))
end


@doc raw"""
    has_edge(g::Graph{T}, source::Int64, target::Int64) where {T <: Union{Directed, Undirected}}

Check for an edge in a graph.

# Examples
Check for the edge $1\to 2$ in the edge graph of a triangle.
```jldoctest
julia> triangle = simplex(2);

julia> g = edgegraph(triangle);

julia> has_edge(g, 1, 2)
true
```
"""
function has_edge(g::Graph{T}, source::Int64, target::Int64) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g)
    return Polymake._has_edge(pmg, source-1, target-1)
end
function has_edge(g::Graph{T}, e::Edge) where {T <: Union{Directed, Undirected}}
    return has_edge(g, e.source, e.target)
end


@doc raw"""
    has_vertex(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}

Check for a vertex in a graph.

# Examples
The edge graph of a triangle only has 3 vertices.
```jldoctest
julia> triangle = simplex(2);

julia> g = edgegraph(triangle);

julia> has_vertex(g, 1)
true

julia> has_vertex(g, 4)
false
```
"""
function has_vertex(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g)
    return Polymake._has_vertex(pmg, v-1)
end


@doc raw"""
    neighbors(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}

Return the neighboring vertices of a vertex `v` in a graph `g`. If the graph is
directed, the neighbors reachable via outgoing edges are returned.

# Examples
```jldoctest
julia> g = Graph{Directed}(5);

julia> add_edge!(g, 1, 3);

julia> add_edge!(g, 3, 4);

julia> neighbors(g, 3)
1-element Vector{Int64}:
 4
```
"""
function neighbors(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g);
    result = Polymake._outneighbors(pmg, v-1)
    return [x+1 for x in result]
end


@doc raw"""
    inneighbors(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}

Return the vertices of a graph `g` that have an edge going towards `v`. For an
undirected graph, all neighboring vertices are returned.

# Examples
```jldoctest
julia> g = Graph{Directed}(5);

julia> add_edge!(g, 1, 3);

julia> add_edge!(g, 3, 4);

julia> inneighbors(g, 3)
1-element Vector{Int64}:
 1

julia> inneighbors(g, 1)
Int64[]
```
"""
function inneighbors(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g);
    result = Polymake._inneighbors(pmg, v-1)
    return [x+1 for x in result]
end


@doc raw"""
    outneighbors(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}

Return the vertices of a graph `g` that are target of an edge coming from `v`.
For an undirected graph, all neighboring vertices are returned.

# Examples
```jldoctest
julia> g = Graph{Directed}(5);

julia> add_edge!(g, 1, 3);

julia> add_edge!(g, 3, 4);

julia> outneighbors(g, 3)
1-element Vector{Int64}:
 4

julia> outneighbors(g, 4)
Int64[]
```
"""
function outneighbors(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g);
    result = Polymake._outneighbors(pmg, v-1)
    return [x+1 for x in result]
end


@doc raw"""
    all_neighbors(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}

Return all vertices of a graph `g` that are connected to the vertex `v` via an
edge, independent of the edge direction.

# Examples
```jldoctest
julia> g = Graph{Directed}(5);

julia> add_edge!(g, 1, 3);

julia> add_edge!(g, 3, 4);

julia> all_neighbors(g, 3)
2-element Vector{Int64}:
 1
 4

julia> all_neighbors(g, 4)
1-element Vector{Int64}:
 3
```
"""
function all_neighbors(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g);
    result = union(Polymake._inneighbors(pmg, v-1), Polymake._outneighbors(pmg, v-1))
    return [x+1 for x in result]
end

@doc raw"""
    incidence_matrix(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Return an unsigned (boolean) incidence matrix representing a graph `g`.

# Examples
```jldoctest
julia> g = Graph{Directed}(5);

julia> add_edge!(g, 1, 3);

julia> add_edge!(g, 3, 4);

julia> incidence_matrix(g)
5×2 IncidenceMatrix
[1]
[]
[1, 2]
[2]
[]
```
"""
function incidence_matrix(g::Graph{T}) where {T <: Union{Directed, Undirected}}
  IncidenceMatrix(Polymake.graph.incidence_matrix(pm_object(g)))
end

@doc raw"""
    signed_incidence_matrix(g::Graph{Directed})

Return a signed incidence matrix representing a directed graph `g`.

# Examples
```jldoctest
julia> g = Graph{Directed}(5);

julia> add_edge!(g,1,2); add_edge!(g,2,3); add_edge!(g,3,4); add_edge!(g,4,5); add_edge!(g,5,1);

julia> signed_incidence_matrix(g)
5×5 Matrix{Int64}:
 -1   0   0   0   1
  1  -1   0   0   0
  0   1  -1   0   0
  0   0   1  -1   0
  0   0   0   1  -1
```
"""
signed_incidence_matrix(g::Graph{Directed}) = convert(Matrix{Int}, Polymake.graph.signed_incidence_matrix(pm_object(g)))

################################################################################
################################################################################
##  Higher order algorithms
################################################################################
################################################################################
@doc raw"""
    automorphism_group_generators(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Return generators of the automorphism group of the graph `g`.

# Examples
```jldoctest
julia> g = complete_graph(4);

julia> automorphism_group_generators(g)
3-element Vector{PermGroupElem}:
 (3,4)
 (2,3)
 (1,2)
```
"""
function automorphism_group_generators(g::Graph{T}) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g);
    result = Polymake.graph.automorphisms(pmg)
    return _pm_arr_arr_to_group_generators(result, nvertices(g))
end


@doc raw"""
    automorphism_group(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Return the automorphism group of the graph `g`.

# Examples
```jldoctest
julia> g = complete_graph(4);

julia> automorphism_group(g)
Permutation group of degree 4
```
"""
function automorphism_group(g::Graph{T}) where {T <: Union{Directed, Undirected}}
    return _gens_to_group(automorphism_group_generators(g))
end


@doc raw"""
    shortest_path_dijkstra(g::Graph{T}, s::Int64, t::Int64; reverse::Bool=false) where {T <: Union{Directed, Undirected}}

Compute the shortest path between two vertices in a graph using Dijkstra's
algorithm. All edges are set to have a length of 1. The optional parameter
indicates whether the edges should be considered reversed.

# Examples
```jldoctest
julia> g = Graph{Directed}(3);

julia> add_edge!(g, 1, 2);

julia> add_edge!(g, 2, 3);

julia> add_edge!(g, 3, 1);

julia> shortest_path_dijkstra(g, 3, 1)
2-element Vector{Int64}:
 3
 1

julia> shortest_path_dijkstra(g, 1, 3)
3-element Vector{Int64}:
 1
 2
 3

julia> shortest_path_dijkstra(g, 3, 1; reverse=true)
3-element Vector{Int64}:
 3
 2
 1
```
"""
function shortest_path_dijkstra(g::Graph{T}, s::Int64, t::Int64; reverse::Bool=false) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g)
    em = Polymake.EdgeMap{T, Int64}(pmg)
    for e in edges(g)
        Polymake._set_entry(em, src(e)-1, dst(e)-1, 1)
    end
    result = Polymake._shortest_path_dijkstra(pmg, em, s-1, t-1, !reverse)
    return Polymake.to_one_based_indexing(result)
end

@doc raw"""
    is_connected(g::Graph{Undirected})

Checks if the undirected graph `g` is connected.

# Examples
```jldoctest
julia> g = Graph{Undirected}(3);

julia> is_connected(g)
false

julia> add_edge!(g, 1, 2);

julia> add_edge!(g, 2, 3);

julia> is_connected(g)
true
```
"""
is_connected(g::Graph{Undirected}) = Polymake.call_function(:graph, :is_connected, pm_object(g))::Bool

function connected_components(g::Graph{Undirected})
    im = Polymake.call_function(:graph, :connected_components, pm_object(g))::IncidenceMatrix
    return [Vector(Polymake.row(im,i)) for i in 1:Polymake.nrows(im)]
end

@doc raw"""
    is_strongly_connected(g::Graph{Directed})

Checks if the directed graph `g` is strongly connected.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> add_edge!(g, 1, 2);

julia> is_strongly_connected(g)
false

julia> add_edge!(g, 2, 1);

julia> is_strongly_connected(g)
true
```
"""
is_strongly_connected(g::Graph{Directed}) = Polymake.call_function(:graph, :is_strongly_connected, pm_object(g))::Bool

@doc raw"""
    strongly_connected_components(g::Graph{Directed})

Return the strongly connected components of a directed graph `g`.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> add_edge!(g, 1, 2);

julia> length(strongly_connected_components(g))
2

julia> add_edge!(g, 2, 1);

julia> strongly_connected_components(g)
1-element Vector{Vector{Int64}}:
 [1, 2]
```
"""
function strongly_connected_components(g::Graph{Directed})
    im = Polymake.call_function(:graph, :strong_components, pm_object(g))::IncidenceMatrix
    return [Vector(Polymake.row(im,i)) for i in 1:Polymake.nrows(im)]
end

@doc raw"""
    is_weakly_connected(g::Graph{Directed})

Checks if the directed graph `g` is weakly connected.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> add_edge!(g, 1, 2);

julia> is_weakly_connected(g)
true
```
"""
is_weakly_connected(g::Graph{Directed}) = Polymake.call_function(:graph, :is_weakly_connected, pm_object(g))::Bool

@doc raw"""
    weakly_connected_components(g::Graph{Directed})

Return the weakly connected components of a directed graph `g`.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> add_edge!(g, 1, 2);

julia> weakly_connected_components(g)
1-element Vector{Vector{Int64}}:
 [1, 2]
```
"""
function weakly_connected_components(g::Graph{Directed})
    im = Polymake.call_function(:graph, :weakly_connected_components, pm_object(g))::IncidenceMatrix
    return [Vector(Polymake.row(im,i)) for i in 1:Polymake.nrows(im)]
end

@doc raw"""
    diameter(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Return the diameter of a (strongly) connected (di-)graph `g`.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> add_edge!(g, 1, 2);

julia> weakly_connected_components(g)
1-element Vector{Vector{Int64}}:
 [1, 2]
```
"""
function diameter(g::Graph{T}) where {T <: Union{Directed, Undirected}}
    if T == Directed && !is_strongly_connected(g) ||
       T == Undirected && !is_connected(g)
        throw(ArgumentError("The (di-)graph must be (strongly) connected!"))
    end
    return Polymake.call_function(:graph, :diameter, pm_object(g))::Int
end

@doc raw"""
    is_isomorphic(g1::Graph{T}, g2::Graph{T}) where {T <: Union{Directed, Undirected}}

Checks if the graph `g1` is isomorphic to the graph `g2`.

# Examples
```jldoctest
julia> is_isomorphic(edgegraph(simplex(3)), dualgraph(simplex(3)))
true

julia> is_isomorphic(edgegraph(cube(3)), dualgraph(cube(3)))
false
```
"""
is_isomorphic(g1::Graph{T}, g2::Graph{T}) where {T <: Union{Directed, Undirected}} = Polymake.graph.isomorphic(pm_object(g1), pm_object(g2))::Bool

@doc raw"""
    is_isomorphic_with_permutation(G1::Graph, G2::Graph) -> Bool, Vector{Int}

Return whether `G1` is isomorphic to `G2` as well as a permutation
of the nodes of `G1` such that both graphs agree.

# Examples
```jldoctest
julia> is_isomorphic_with_permutation(edgegraph(simplex(3)), dualgraph(simplex(3)))
(true, [1, 2, 3, 4])

```
"""
function is_isomorphic_with_permutation(G1::Graph, G2::Graph)
  f12 = Polymake.graph.find_node_permutation(G1.pm_graph, G2.pm_graph)
  if isnothing(f12)
    return false, Vector{Int}()
  end
  return true, Polymake.to_one_based_indexing(f12)
end

@doc raw"""
    _is_equal_up_to_permutation_with_permutation(A1::MatElem, A2::MatElem) -> Bool, Vector{Int}

Return a permutation `I` such that `A1[I,I] == A2` and whether it exists.

The method assumes that both matrices are symmetric, their diagonal entries
are all equal (and so irrelevant) and the off-diagonal entries are either ``0``
or ``1``. It is assumed that `A1` and `A2` are symmetric and
their upper triangular part is ignored.
"""
function _is_equal_up_to_permutation_with_permutation(A1::MatElem, A2::MatElem)
  g1 = graph_from_adjacency_matrix(Undirected, A1)
  g2 = graph_from_adjacency_matrix(Undirected, A2)
  b, T = is_isomorphic_with_permutation(g1, g2)
  if b
    @assert A1[T, T] == A2
  end
  return b, T
end


################################################################################
################################################################################
##  Standard constructions
################################################################################
################################################################################
@doc raw"""
    edgegraph(p::Polyhedron)

Return the edge graph of a `Polyhedron`, vertices of the graph correspond to
vertices of the polyhedron, there is an edge between two vertices if the
polyhedron has an edge between the corresponding vertices. The resulting graph
is `Undirected`.

# Examples
Construct the edge graph of the cube. Like the cube it has 8 vertices and 12
edges.
```jldoctest
julia> c = cube(3);

julia> g = edgegraph(c);

julia> number_of_vertices(g)
8

julia> number_of_edges(g)
12
```
"""
function edgegraph(p::Polyhedron)
    pmg = pm_object(p).GRAPH.ADJACENCY
    return Graph{Undirected}(pmg)
end

@doc raw"""
    dualgraph(p::Polyhedron)

Return the dual graph of a `Polyhedron`, vertices of the graph correspond to
facets of the polyhedron and there is an edge between two vertices if the
corresponding facets are neighboring, meaning their intersection is a
codimension 2 face of the polyhedron.

For bounded polyhedra containing 0 in the interior this is the same as the edge
graph the polar dual polyhedron.

# Examples
Construct the dual graph of the cube. This is the same as the edge graph of the
octahedron, so it has 6 vertices and 12 edges.
```jldoctest
julia> c = cube(3);

julia> g = dualgraph(c);

julia> number_of_vertices(g)
6

julia> number_of_edges(g)
12
```
"""
function dualgraph(p::Polyhedron)
    pmg = pm_object(p).DUAL_GRAPH.ADJACENCY
    return Graph{Undirected}(pmg)
end



@doc raw"""
    complete_graph(n::Int64)

Assemble the undirected complete graph on `n` nodes.

# Examples
```jldoctest
julia> g = complete_graph(3);

julia> collect(edges(g))
3-element Vector{Edge}:
 Edge(2, 1)
 Edge(3, 1)
 Edge(3, 2)
```
"""
function complete_graph(n::Int64)
    bigobj = Polymake.graph.complete(n)
    return Graph{Undirected}(bigobj.ADJACENCY)
end


@doc raw"""
    complete_bipartite_graph(n::Int64, m::Int64)

Assemble the undirected complete bipartite graph between `n` and `m` nodes.

# Examples
```jldoctest
julia> g = complete_bipartite_graph(2,2);

julia> collect(edges(g))
4-element Vector{Edge}:
 Edge(3, 1)
 Edge(3, 2)
 Edge(4, 1)
 Edge(4, 2)
```
"""
function complete_bipartite_graph(n::Int64, m::Int64)
    bigobj = Polymake.graph.complete_bipartite(n, m)
    return Graph{Undirected}(bigobj.ADJACENCY)
end



@doc raw"""
    visualize(G::Graph{T}) where {T <: Union{Polymake.Directed, Polymake.Undirected}}

Visualize a graph.
"""
function visualize(G::Graph{T}) where {T <: Union{Polymake.Directed, Polymake.Undirected}}
    BigGraph = Polymake.graph.Graph(ADJACENCY=pm_object(G))
    Polymake.visual(BigGraph)
end



# Some standard polytopes from graphs
@doc raw"""
    fractional_cut_polytope(G::Graph{Undirected})

Construct the fractional cut polytope of the graph $G$.


# Examples
```jldoctest
julia> G = complete_graph(4);

julia> fractional_cut_polytope(G)
Polytope in ambient dimension 6
```
"""
fractional_cut_polytope(G::Graph{Undirected}) = polyhedron(Polymake.polytope.fractional_cut_polytope(pm_object(G)))


@doc raw"""
    fractional_matching_polytope(G::Graph{Undirected})

Construct the fractional matching polytope of the graph $G$.


# Examples
```jldoctest
julia> G = complete_graph(4);

julia> fractional_matching_polytope(G)
Polytope in ambient dimension 6
```
"""
fractional_matching_polytope(G::Graph{Undirected}) = polyhedron(Polymake.polytope.fractional_matching_polytope(pm_object(G)))


################################################################################
################################################################################
##  Printing
################################################################################
################################################################################
_to_string(::Type{Polymake.Directed}) = "Directed"
_to_string(::Type{Polymake.Undirected}) = "Undirected"

function Base.show(io::IO, ::MIME"text/plain", G::Graph{T}) where {T <: Union{Polymake.Directed, Polymake.Undirected}}
  if nedges(G) > 0
    println(io, "$(_to_string(T)) graph with $(nvertices(G)) nodes and the following edges:")  # at least one new line is needed
    for e in edges(G)
      print(io, "($(src(e)), $(dst(e)))")
    end
  else
    print(io, "$(_to_string(T)) graph with $(nvertices(G)) nodes and no edges")
  end
end

function Base.show(io::IO, G::Graph{T})  where {T <: Union{Polymake.Directed, Polymake.Undirected}}
  if get(io, :supercompact, false)
    print(io, "$(_to_string(T)) graph")
  else
    print(io, "$(_to_string(T)) graph with $(nvertices(G)) nodes and $(nedges(G)) edges")
  end
end

################################################################################
################################################################################
##  Phylogenetic Trees
################################################################################
################################################################################
@doc raw"""
    phylogenetic_tree(T::Type{<:Union{Float64, QQFieldElem}}, newick::String)

Constructs a phylogenetic tree with Newick representation `newick`. `T` indicates 
the numerical type of the edge lengths.

# Examples
Make a phylogenetic tree with 4 leaves from its Newick representation and print 
its taxa and cophenetic matrix.
```jldoctest
julia> phylo_t = phylogenetic_tree(Float64, "((H:3,(C:1,B:1):2):1,G:4);");

julia> taxa(phylo_t)
4-element Vector{String}:
 "B"
 "C"
 "G"
 "H"

julia> cophenetic_matrix(phylo_t)
4×4 Matrix{Float64}:
 0.0  2.0  8.0  6.0
 2.0  0.0  8.0  6.0
 8.0  8.0  0.0  8.0
 6.0  6.0  8.0  0.0
```
"""
function phylogenetic_tree(T::Type{<:Union{Float64, QQFieldElem}}, newick::String)
  pm_ptree = Polymake.graph.PhylogeneticTree{Polymake.convert_to_pm_type(T)}(NEWICK = newick)

  # load graph properties
  pm_ptree.ADJACENCY
  
  return PhylogeneticTree{T}(pm_ptree)
end

@doc raw"""
   phylogenetic_tree(M::Matrix{T}, taxa::Vector{String}) where T <: Union{Float64, QQFieldElem}

Constructs a phylogenetic tree with cophenetic matrix `M` and taxa `taxa`. The matrix `M` must be
ultrametric, otherwise an error will be thrown.

# Examples
Make a phylogenetic tree on 4 taxa with given cophenetic matrix and print one Newick representation.

```jldoctest
julia> mat = [0. 2 8 6; 2 0 8 6; 8 8 0 8; 6 6 8 0]
4×4 Matrix{Float64}:
 0.0  2.0  8.0  6.0
 2.0  0.0  8.0  6.0
 8.0  8.0  0.0  8.0
 6.0  6.0  8.0  0.0

julia> tax = ["Bonobo", "Chimpanzee", "Gorilla", "Human"]
4-element Vector{String}:
 "Bonobo"
 "Chimpanzee"
 "Gorilla"
 "Human"

julia> tree_mat = phylogenetic_tree(mat, tax);

julia> newick(tree_mat)
"Gorilla:4,(Human:3,(Bonobo:1,Chimpanzee:1):2):1;"
```
"""
function phylogenetic_tree(M::Matrix{Float64}, taxa::Vector{String})
  n_taxa = length(taxa)
  @req (n_taxa, n_taxa) == size(M) "Number of taxa should match the rows and columns of the given matrix"
  pm_ptree = Polymake.graph.PhylogeneticTree{Float64}(COPHENETIC_MATRIX = M, TAXA = taxa)
  return PhylogeneticTree{Float64}(pm_ptree)
end

function phylogenetic_tree(M::QQMatrix, taxa::Vector{String})
  n_taxa = length(taxa)
  @req (n_taxa, n_taxa) == size(M) "Number of taxa should match the rows and columns of the given matrix"
  pm_T = Polymake.convert_to_pm_type(QQFieldElem)
  cp_M = convert(Matrix{pm_T}, Matrix{QQFieldElem}(M))

  pm_ptree = Polymake.graph.PhylogeneticTree{pm_T}(
    COPHENETIC_MATRIX = M, TAXA = taxa
  )
  return PhylogeneticTree{QQFieldElem}(pm_ptree)
end

@doc raw"""
    adjacency_tree(ptree::PhylogeneticTree)

Returns the underlying graph of the phylogenetic tree `ptree`. It will be an directed tree with edges directed away from the root (labeled with 1).

# Examples
Make a phylogenetic tree with given Newick format and print its underlying graph.

```jldoctest
julia> ptree = phylogenetic_tree(Float64, "((H:3,(C:1,B:1):2):1,G:4);");

julia> adjacency_tree(ptree)
Directed graph with 7 nodes and the following edges:
(1, 2)(1, 7)(2, 3)(2, 4)(4, 5)(4, 6)
```
"""
function adjacency_tree(ptree::PhylogeneticTree)
  udir_tree = Graph{Undirected}(ptree.pm_ptree.ADJACENCY)
  n = nv(udir_tree)
  # list_edges = collect(edges(udir_tree))
  dir_tree = Graph{Directed}(n)
  
  queue = [1]
  visited = fill(false, n)
  visited[1] = true
  while length(queue) > 0
    x = popfirst!(queue)
    for y in neighbors(udir_tree, x)
      if visited[y] == false
        add_edge!(dir_tree, x, y)
        push!(queue, y)
        visited[y] = true
      end
    end
  end
  
  return dir_tree
end

function Base.show(io::IO, ptree::PhylogeneticTree{T}) where T
  print(io, "Phylogenetic tree with $T type coefficients")
end

@doc raw"""
    equidistant(ptree::PhylogeneticTree)

Checks if the phylogenetic tree `ptree` is equidistant.

# Examples
Make a phylogenetic tree with given Newick format and check if it is equidistant.

```jldoctest
julia> ptree = phylogenetic_tree(Float64, "((H:3,(C:1,B:1):2):1,G:4);");

julia> equidistant(ptree)
true
```
"""
function equidistant(ptree::PhylogeneticTree)
  return ptree.pm_ptree.EQUIDISTANT
end


@doc raw"""
    cophenetic_matrix(ptree::PhylogeneticTree)

Returns the cophenetic matrix of the phylogenetic tree `ptree`.

# Examples
Make a phylogenetic tree with given Newick format and print its cophenetic matrix.

```jldoctest
julia> ptree = phylogenetic_tree(Float64, "((H:3,(C:1,B:1):2):1,G:4);");

julia> cophenetic_matrix(ptree)
4×4 Matrix{Float64}:
 0.0  2.0  8.0  6.0
 2.0  0.0  8.0  6.0
 8.0  8.0  0.0  8.0
 6.0  6.0  8.0  0.0
```
"""
function cophenetic_matrix(ptree::PhylogeneticTree)
  return convert(Matrix, ptree.pm_ptree.COPHENETIC_MATRIX)
end

@doc raw"""
    taxa(ptree::PhylogeneticTree)

Returns the taxa of the phylogenetic tree `ptree`.

# Examples
Make a phylogenetic tree with given Newick format and print its taxa.

```jldoctest
julia> ptree = phylogenetic_tree(Float64, "((H:3,(C:1,B:1):2):1,G:4);");

julia> taxa(ptree)
4-element Vector{String}:
 "B"
 "C"
 "G"
 "H"
```
"""
function taxa(ptree::PhylogeneticTree)
  return convert(Array{String}, ptree.pm_ptree.TAXA)
end

@doc raw"""
    newick(ptree::PhylogeneticTree)

Returns a Newick representation of the phylogenetic tree `ptree`.

# Examples
Make a phylogenetic tree from a matrix and print a Newick representation of it.

```jldoctest
julia> mat = [0. 2 8 6; 2 0 8 6; 8 8 0 8; 6 6 8 0]
4×4 Matrix{Float64}:
 0.0  2.0  8.0  6.0
 2.0  0.0  8.0  6.0
 8.0  8.0  0.0  8.0
 6.0  6.0  8.0  0.0

julia> tax = ["Bonobo", "Chimpanzee", "Gorilla", "Human"]
4-element Vector{String}:
 "Bonobo"
 "Chimpanzee"
 "Gorilla"
 "Human"

julia> tree_mat = phylogenetic_tree(mat, tax);

julia> newick(tree_mat)
"Gorilla:4,(Human:3,(Bonobo:1,Chimpanzee:1):2):1;"
```
"""
function newick(ptree::PhylogeneticTree)
  return convert(String, ptree.pm_ptree.NEWICK)
end


@doc raw"""
    tropical_median_consensus(arr::Vector{PhylogeneticTree{T}})

Computes the tropical median consensus tree of the phylogenetic trees from
the vector `arr`.

# Examples
Compute the tropical median consensus of three trees and print one of its
Newick representations.

```jldoctest
julia> t1 = phylogenetic_tree(Float64, "((H:30,(C:10,B:10):20):10,G:40);");

julia> t2 = phylogenetic_tree(Float64, "(((H:10,C:10):20,B:30):10,G:40);");

julia> t3 = phylogenetic_tree(Float64, "((H:25,C:25):15,(B:15,G:15):25);");

julia> arr = [t1, t2, t3];

julia> tc = tropical_median_consensus(arr);

julia> newick(tc)
"G:40,(B:35,(C:30,H:30):5):5;"
```
"""
function tropical_median_consensus(arr::Vector{PhylogeneticTree{T}}) where {T <: Union{Float64, QQFieldElem}}

  n = length(arr)
  @req n > 0 "The vector must not be empty"

  phylo_type = Polymake.bigobject_type(arr[1].pm_ptree)
  pm_arr = Polymake.Array{Polymake.BigObject}(phylo_type, n)
  
  for i in 1:n
    pm_arr[i] = arr[i].pm_ptree
  end
  
  pm_cons_tree = Polymake.tropical.tropical_median_consensus(pm_arr)
  return PhylogeneticTree{T}(pm_cons_tree)
end


#function tropical_median_consensus(trees...)
#  return tropical_median_consensus(trees)
#end



