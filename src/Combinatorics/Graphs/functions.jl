struct PhylogeneticTree{T <: Union{Float64, QQFieldElem}}
  pm_ptree::Polymake.LibPolymake.BigObjectAllocated
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

julia> n_vertices(g)
5

julia> n_edges(g)
0
```
"""
function Graph{T}(nverts::Int64) where {T <: Union{Directed, Undirected}}
    pmg = Polymake.Graph{T}(nverts)
    return Graph{T}(pmg)
end

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
  pm_ptree = Polymake.graph.PhylogeneticTree{Rational}(
    COPHENETIC_MATRIX = M, TAXA = taxa
  )
  return PhylogeneticTree{QQFieldElem}(pm_ptree)
end

@doc raw"""
    adjacency_tree(ptree::PhylogeneticTree)

Returns the underlying graph of the phylogenetic tree `ptree`.

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


_has_node(G::Graph, node::Int64) = 0 < node <= n_vertices(G)

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

julia> n_edges(g)
1
```
"""
function add_edge!(g::Graph{T}, source::Int64, target::Int64) where {T <: Union{Directed, Undirected}}
  _has_node(g, source) && _has_node(g, target) || return false
  old_nedges = n_edges(g)
  Polymake._add_edge(pm_object(g), source-1, target-1)
  return n_edges(g) == old_nedges + 1
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

julia> n_edges(g)
1

julia> rem_edge!(g, 1, 2)
true

julia> n_edges(g)
0
```
"""
function rem_edge!(g::Graph{T}, s::Int64, t::Int64) where {T <: Union{Directed, Undirected}}
  has_edge(g, s, t) || return false
  old_nedges = n_edges(g)
  Polymake._rem_edge(pm_object(g), s-1, t-1)
  return n_edges(g) == old_nedges - 1
end


@doc raw"""
    add_vertex!(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Add a vertex to the graph `g`. Return `true` if there a new vertex was actually
added.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> n_vertices(g)
2

julia> add_vertex!(g)
true

julia> n_vertices(g)
3
```
"""
function add_vertex!(g::Graph{T}) where {T <: Union{Directed, Undirected}}
    pmg = pm_object(g)
    old_nvertices = n_vertices(g)
    Polymake._add_vertex(pmg)
    return n_vertices(g) - 1 == old_nvertices
end


@doc raw"""
    rem_vertex!(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}

Remove the vertex `v` from the graph `g`. Return `true` if node `v` existed and
was actually removed, `false` otherwise.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> n_vertices(g)
2

julia> rem_vertex!(g, 1)
true

julia> n_vertices(g)
1
```
"""
function rem_vertex!(g::Graph{T}, v::Int64) where {T <: Union{Directed, Undirected}}
  _has_node(g, v) || return false
  pmg = pm_object(g)
  old_nvertices = n_vertices(g)
  result = Polymake._rem_vertex(pmg, v-1)
  Polymake._squeeze(pmg)
  return n_vertices(g) + 1 == old_nvertices
end


@doc raw"""
    add_vertices!(g::Graph{T}, n::Int64) where {T <: Union{Directed, Undirected}}

Add a `n` new vertices to the graph `g`. Return the number of vertices that
were actually added to the graph `g`.

# Examples
```jldoctest
julia> g = Graph{Directed}(2);

julia> n_vertices(g)
2

julia> add_vertices!(g, 5);

julia> n_vertices(g)
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
    n_vertices(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Return the number of vertices of a graph.

# Examples
The edge graph of the cube has eight vertices, just like the cube itself.
```jldoctest
julia> c = cube(3);

julia> g = edgegraph(c);

julia> n_vertices(g)
8
```
"""
function n_vertices(g::Graph{T}) where {T <: Union{Directed, Undirected}}
    return Polymake.nv(pm_object(g))
end

@doc raw"""
    n_edges(g::Graph{T}) where {T <: Union{Directed, Undirected}}

Checks if the phylogenetic tree `ptree` is equidistant.

# Examples
Make a phylogenetic tree with given Newick format and check if it is equidistant.

```jldoctest
julia> ptree = phylogenetic_tree(Float64, "((H:3,(C:1,B:1):2):1,G:4);");

<<<<<<< HEAD
julia> equidistant(ptree)
=======
julia> g = edgegraph(c);

julia> n_edges(g)
12
```
"""
function n_edges(g::Graph{T}) where {T <: Union{Directed, Undirected}}
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
    return EdgeIterator(Polymake.edgeiterator(pm_object(g)), n_edges(g))
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
>>>>>>> origin/master
true
```
"""
function equidistant(ptree::PhylogeneticTree)
  return pm_object(ptree).EQUIDISTANT::Bool
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
function cophenetic_matrix(ptree::PhylogeneticTree{Float64})
  return convert(Matrix, pm_object(ptree).COPHENETIC_MATRIX)::Matrix{Float64}
end

function cophenetic_matrix(ptree::PhylogeneticTree{QQFieldElem})
  return matrix(QQ, pm_object(ptree).COPHENETIC_MATRIX)::QQMatrix
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
  return convert(Array{String}, pm_object(ptree).TAXA)::Array{String}
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
  return convert(String, pm_object(ptree).NEWICK)::String
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

  phylo_type = Polymake.bigobject_type(pm_object(first(arr)))
  pm_arr = Polymake.Array{Polymake.BigObject}(phylo_type, n)
  
  pm_arr .= pm_object.(arr)
    
  pm_cons_tree = Polymake.tropical.tropical_median_consensus(pm_arr)
  return PhylogeneticTree{T}(pm_cons_tree)
end


@doc raw"""
    tropical_median_consensus(trees::Vararg{PhylogeneticTree, N}) where {N}

Computes the tropical median consensus tree of any number of phylogenetic trees
given as parameters.

# Examples
Compute the tropical median consensus of three trees and print one of its
Newick representations.

```jldoctest
julia> t1 = phylogenetic_tree(Float64, "((H:30,(C:10,B:10):20):10,G:40);");

julia> t2 = phylogenetic_tree(Float64, "(((H:10,C:10):20,B:30):10,G:40);");

julia> t3 = phylogenetic_tree(Float64, "((H:25,C:25):15,(B:15,G:15):25);");

julia> tc = tropical_median_consensus(t1, t2, t3);

julia> newick(tc)
"G:40,(B:35,(C:30,H:30):5):5;"
```
"""
<<<<<<< HEAD
function tropical_median_consensus(trees::Vararg{PhylogeneticTree, N}) where {N}
  return tropical_median_consensus(collect(trees))
end
=======
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
    return _pm_arr_arr_to_group_generators(result, n_vertices(g))
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

julia> n_vertices(g)
8

julia> n_edges(g)
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

julia> n_vertices(g)
6

julia> n_edges(g)
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
  if n_edges(G) > 0
    println(io, "$(_to_string(T)) graph with $(n_vertices(G)) nodes and the following edges:")  # at least one new line is needed
    for e in edges(G)
      print(io, "($(src(e)), $(dst(e)))")
    end
  else
    print(io, "$(_to_string(T)) graph with $(n_vertices(G)) nodes and no edges")
  end
end

function Base.show(io::IO, G::Graph{T})  where {T <: Union{Polymake.Directed, Polymake.Undirected}}
  if get(io, :supercompact, false)
    print(io, "$(_to_string(T)) graph")
  else
    print(io, "$(_to_string(T)) graph with $(n_vertices(G)) nodes and $(n_edges(G)) edges")
  end
end

function graph_from_edges(::Type{T},
                          edges::Vector{Edge},
                          n_vertices::Int=-1) where {T <: Union{Directed, Undirected}}

  n_needed = maximum(reduce(append!,[[src(e),dst(e)] for e in edges]))
  @req (n_vertices >= n_needed || n_vertices < 0)  "n_vertices must be at least the maximum vertex in the edges"

  g = Graph{T}(max(n_needed, n_vertices))
  for e in edges
    add_edge!(g, src(e), dst(e))
  end

  return g
end

function graph_from_edges(::Type{T},
                          edges::EdgeIterator,
                          n_vertices::Int=-1) where {T <: Union{Directed, Undirected}}
  return graph_from_edges(T, collect(edges), n_vertices)
end

@doc raw"""
    graph_from_edges(edges::Vector{Vector{Int}})
    graph_from_edges(::Type{T}, edges::Vector{Vector{Int}}, n_vertices::Int=-1) where {T <:Union{Directed, Undirected}}

Creates a graph from a vector of edges. There is an optional input for number of vertices, `graph_from_edges`  will
ignore any negative integers and throw an error when the input is less than the maximum vertex index in edges.

# Examples
```jldoctest
julia> G = graph_from_edges([[1,3],[3,5],[4,5],[2,4],[2,3]])
Undirected graph with 5 nodes and the following edges:
(3, 1)(3, 2)(4, 2)(5, 3)(5, 4)

julia> G = graph_from_edges(Directed, [[1,3]], 4)
Directed graph with 4 nodes and the following edges:
(1, 3)
```
"""
function graph_from_edges(::Type{T},
                          edges::Vector{Vector{Int}},
                          n_vertices::Int=-1) where {T <: Union{Directed, Undirected}}
  return graph_from_edges(T, [Edge(e[1], e[2]) for e in edges], n_vertices)
end

function graph_from_edges(edges::Vector{Vector{Int}},
                          n_vertices::Int=-1)
  return graph_from_edges(Undirected, [Edge(e[1], e[2]) for e in edges], n_vertices)
end
>>>>>>> origin/master
