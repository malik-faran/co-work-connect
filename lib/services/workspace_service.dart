import 'package:cwc/models/workspace_model.dart';
import 'package:cwc/services/supabase_service.dart';
/// Provides methods to create, read, update, and delete workspaces
class WorkspaceService {
  /// Supabase client instance for database operations
  final _supabase = SupabaseService.client;

  /// Retrieves all available workspaces from the database
  Future<List<WorkspaceModel>> getAllWorkspaces() async {
    final response = await _supabase
        .from('workspaces')
        .select()
        .eq('is_available', true)
        .order('created_at', ascending: false);

    return response.map((w) => WorkspaceModel.fromWorkspaceMap(w)).toList();
  }

  /// Returns a stream of all available workspaces
  /// Automatically updates when workspaces change in the database
  Stream<List<WorkspaceModel>> getAllWorkspacesStream() {
    return _supabase
        .from('workspaces')
        .stream(primaryKey: ['id'])
        .eq('is_available', true)
        .order('created_at', ascending: false)
        .map(
          (data) =>
              data.map((w) => WorkspaceModel.fromWorkspaceMap(w)).toList(),
        )
        .distinct();
  }

  /// Retrieves all workspaces owned by a specific owner
  /// Returns workspaces sorted by creation date (newest first)
  Future<List<WorkspaceModel>> getWorkspacesByOwnerId(String ownerId) async {
    final response = await _supabase
        .from('workspaces')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return response.map((w) => WorkspaceModel.fromWorkspaceMap(w)).toList();
  }

  /// Retrieves a single workspace by its ID
  /// Returns null if workspace is not found
  Future<WorkspaceModel?> getWorkspaceById(String id) async {
    final data = await _supabase
        .from('workspaces')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data == null ? null : WorkspaceModel.fromWorkspaceMap(data);
  }

  /// Creates a new workspace in the database
  /// Throws an exception if creation fails
  Future<void> createWorkspace(WorkspaceModel workspace) async {
    try {
      final workspaceData = workspace.toWorkspaceMap();
      workspaceData.removeWhere((key, value) => value == null);

      await _supabase.from('workspaces').insert(workspaceData);
    } catch (e) {
      throw Exception('Failed to create workspace: ${e.toString()}');
    }
  }

  /// Updates an existing workspace in the database
  Future<void> updateWorkspace(WorkspaceModel workspace) async {
    final workspaceData = workspace
        .copyWorkspace(updatedAt: DateTime.now())
        .toWorkspaceMap();
    workspaceData.removeWhere((key, value) => value == null);

    await _supabase
        .from('workspaces')
        .update(workspaceData)
        .eq('id', workspace.id);
  }

  /// Deletes a workspace from the database
  Future<void> deleteWorkspace(String id) async {
    await _supabase.from('workspaces').delete().eq('id', id);
  }

  /// Searches workspaces by query string
  Future<List<WorkspaceModel>> searchWorkspaces(String query) async {
    final allWorkspaces = await getAllWorkspaces();
    final String lowerQuery = query.toLowerCase();
    return allWorkspaces.where((workspace) {
      return workspace.name.toLowerCase().contains(lowerQuery) ||
          workspace.city.toLowerCase().contains(lowerQuery) ||
          workspace.address.toLowerCase().contains(lowerQuery) ||
          workspace.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Filters workspaces by amenities
  Future<List<WorkspaceModel>> filterWorkspacesByAmenities(
    List<String> amenities,
  ) async {
    final allWorkspaces = await getAllWorkspaces();
    return allWorkspaces.where((workspace) {
      return amenities.every(
        (amenity) => workspace.amenities
            .map((a) => a.toLowerCase())
            .contains(amenity.toLowerCase()),
      );
    }).toList();
  }

  /// Returns a stream of workspaces sorted by creation date
  Stream<List<WorkspaceModel>> getWorkspacesStream() {
    return _supabase
        .from('workspaces')
        .stream(primaryKey: ['id'])
        .eq('is_available', true)
        .map((data) {
          final workspaces = data
              .map((w) => WorkspaceModel.fromWorkspaceMap(w))
              .toList();
          workspaces.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return workspaces;
        });
  }
}
