using Godot;

public partial class PlayerInteractor : RayCast3D // Turunan dari RayCast3D
{
	private InteractableObject _currentTarget = null;

	public override void _PhysicsProcess(double delta)
	{
		// 1. Deteksi Sorotan (Hover)
		if (IsColliding())
		{
			// Ambil objek yang ditabrak dan pastikan tipenya adalah InteractableObject
			var collider = GetCollider() as InteractableObject;

			if (collider != null && collider.IsInGroup("Interactable"))
			{
				// Jika melihat objek baru
				if (collider != _currentTarget)
				{
					if (_currentTarget != null) _currentTarget.HideOutline();

					_currentTarget = collider;
					_currentTarget.ShowOutline();
				}

				// 2. Deteksi Tombol 'E' (Interaksi)
				if (Input.IsActionJustPressed("interact"))
				{
					_currentTarget.Interact(); // Panggil fungsi interaksi di benda tersebut
					
					_currentTarget.HideOutline();
					_currentTarget = null;
				}
				
				return;
			}
		}

		// 3. Matikan outline jika tidak menyorot benda apa-apa
		if (_currentTarget != null)
		{
			_currentTarget.HideOutline();
			_currentTarget = null;
		}
	}
}
