using Godot;

public partial class InteractableObject : RigidBody3D
{
	private MeshInstance3D _mesh;
	private Material _outlineMaterial;

	public override void _Ready()
	{
		_mesh = GetNode<MeshInstance3D>("MeshInstance3D");
		_outlineMaterial = GD.Load<Material>("res://Graphics/OutlineMaterial.tres"); // Pastikan path ini benar
	}

	public void ShowOutline()
	{
		if (_mesh != null) _mesh.MaterialOverlay = _outlineMaterial;
	}

	public void HideOutline()
	{
		if (_mesh != null) _mesh.MaterialOverlay = null;
	}

	// Fungsi khusus yang akan dipanggil oleh PlayerInteractor saat tombol E ditekan
	public void Interact()
	{
		GD.Print("Item berhasil diambil!");
		
		// Di sinilah kamu bisa menambahkan logika lain di masa depan,
		// misalnya: menambahkan item ke dalam sistem Inventory pemain.

		QueueFree(); // Hancurkan objek dari dunia
	}
}
