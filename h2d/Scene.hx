package h2d;
import h2d.filter.Filter;
import hxd.Math;

/**
	Viewport alignment when scaling mode supports it.
**/
enum ScaleModeAlign {
	/** Anchor Scene viewport horizontally to left side of the window. When passed to verticalAlign it will be treated as Center. **/
	Left;
	/** Anchor Scene viewport horizontally to right side of the window. When passed to verticalAlign it will be treated as Center. **/
	Right;
	/** Anchor to the center of window. **/
	Center;
	/** Anchor Scene viewport vertically to the top of a window. When passed to horizontalAlign it will be treated as Center. **/
	Top;
	/** Anchor Scene viewport vertically to the bottom of a window. When passed to horizontalAlign it will be treated as Center. **/
	Bottom;
}

/**
	Scaling mode of the 2D Scene.
	See `ScaleMode2D` sample for showcase.
**/
enum ScaleMode {

	/**
		Matches scene size to window size. `width` and `height` of Scene will match window size. Default scaling mode.
	**/
	Resize;

	/**
		Sets constant Scene size and stretches it to cover entire window. This behavior is same as old `setFixedSize` method.
	**/
	Stretch(width : Int, height : Int);

	/**
		Sets constant scene size and upscales it with preserving aspect-ratio to fit the window.
		If `integerScale` is `true` - scaling will be performed  with only integer increments (1x, 2x, 3x, ...). Default: `false`
		`horizontalAlign` controls viewport anchoring horizontally. Accepted values are `Left`, `Center` and `Right`. Default: `Center`
		`verticalAlign` controls viewport anchoring vertically. Accepted values are `Top`, `Center` and `Bottom`. Default: `Center`
		With `800x600` window, `LetterBox(320, 260)` will result in center-aligned Scene of size `320x260` upscaled to fit into screen.
	**/
	LetterBox(width : Int, height : Int, ?integerScale : Bool, ?horizontalAlign : ScaleModeAlign, ?verticalAlign : ScaleModeAlign);

	/**
		Sets constant Scene size, scale and alignment. Does not perform any adaptation to the screen apart from alignment.
		`horizontalAlign` controls viewport anchoring horizontally. Accepted values are `Left`, `Center` and `Right`. Default: `Center`
		`verticalAlign` controls viewport anchoring vertically. Accepted values are `Top`, `Center` and `Bottom`. Default: `Center`
		With `800x600` window, `Fixed(200, 150, 2, Left, Center)` will result in Scene size of `200x150`, and visually upscaled to `400x300`, and aligned to middle-left of the window.
	**/
	Fixed(width : Int, height: Int, zoom : Float, ?horizontalAlign : ScaleModeAlign, ?verticalAlign : ScaleModeAlign);

	/**
		Upscales/downscales Scene according to `level` and matches Scene size to `ceil(window size / level)`.
		With `800x600` window, `Zoom(2)` will result in `400x300` Scene size upscaled to fill entire window.
	**/
	Zoom(level : Float);

	/**
		Ensures that Scene size will be of minimum specified size.
		Automatically calculates zoom level based on provided size according to `min(window width / min width, window height / min height)`, then applies same scaling as `Zoom(level)`.
		Behavior is similiar to LetterBox, however instead of letterboxing effect, Scene size will change to cover the letterboxed parts.
		`minWidth` or `minHeight` can be set to `0` in order to force scaling adjustment account only for either horizontal of vertical window size.
		If `integerScale` is `true` - scaling will be performed  with only integer increments (1x, 2x, 3x, ...). Default: `false`
		With `800x600` window, `AutoZoom(320, 260, false)` will result in Scene size of `347x260`. `AutoZoom(320, 260, true)` will result in size of `400x300`.
	**/
	AutoZoom(minWidth : Int, minHeight : Int, ?integerScaling : Bool);
}

/**
	h2d.Scene is the root class for a 2D scene. All root objects are added to it before being drawn on screen.
**/
class Scene extends Layers implements h3d.IDrawable implements hxd.SceneEvents.InteractiveScene {

	/**
		The current width (in pixels) of the scene. Can change if the screen gets resized or `scaleMode` changes.
	**/
	public var width(default,null) : Int;

	/**
		The current height (in pixels) of the scene. Can change if the screen gets resized or `scaleMode` changes.
	**/
	public var height(default, null) : Int;

	/**
		Viewport horizontal scale transform value. Converts from scene space to screen space of [0, 2] range.
	**/
	var viewportA(default, null) : Float;
	/**
		Viewport vertical scale transform value. Converts from scene space to screen space of [0, 2] range.
	**/
	var viewportD(default, null) : Float;
	/**
		Horizontal viewport offset relative to top-left corner of the window. Can change if the screen gets resized or `scaleMode` changes.
		Offset is in screen-space coordinates: [-1, 1] where 0 is center of the window.
	**/
	var viewportX(default, null) : Float;
	/**
		Vertical viewport offset relative to top-left corner of the window. Can change if the screen gets resized or `scaleMode` changes.
		Offset is in screen-space coordinates: [-1, 1] where 0 is center of the window.
	**/
	var viewportY(default, null) : Float;

	/**
		Horizontal viewport offset relative to top-left corner of the window in pixels.
		Assigned if the screen gets resized or `scaleMode` changes.
	**/
	var offsetX(default, null) : Float;
	/**
		Vertical viewport offset relative to top-left corner of the window in pixels.
		Assigned if the screen gets resized or `scaleMode` changes.
	**/
	var offsetY(default, null) : Float;

	/**
		Horizontal scale of a scene when rendering to screen.
		Can change if the screen gets resized or `scaleMode` changes.
	**/
	public var viewportScaleX(default, null) : Float;
	/**
		Vertical scale of a scene when rendering to screen.
		Can change if the screen gets resized or `scaleMode` changes.
	**/
	public var viewportScaleY(default, null) : Float;

	/**
		The current mouse X coordinates (in pixel) relative to the scene.
	**/
	public var mouseX(get, null) : Float;

	/**
		The current mouse Y coordinates (in pixel) relative to the scene.
	**/
	public var mouseY(get, null) : Float;

	/**
		The zoom factor of the scene, allows to set a fixed x2, x4 etc. zoom for pixel art
		When setting a zoom > 0, the scene resize will be automaticaly managed.
	**/
	@:deprecated("zoom is deprecated, use scaleMode = Zoom(v) instead")
	public var zoom(get, set) : Int;

	/**
		Scene scaling mode. ( default : Fill )
		Important thing to keep in mind - Scene does not clip rendering to it's scaled size and
		graphics can render outside of it. However `drawTile` does check for those bounds and
		will clip out tiles that are outside of the scene bounds.
	**/
	public var scaleMode(default, set) : ScaleMode = Resize;

	/**
		List of all cameras attached to the Scene. Should contain at least one camera to render (created by default).
		Override `h2d.Camera.layerVisible` method to filter out specific layers from camera rendering.
		To add or remove cameras use `addCamera` and `removeCamera` methods.
	**/
	public var cameras(get, never) : haxe.ds.ReadOnlyArray<Camera>;
	var _cameras : Array<Camera>;
	/**
		Alias to first camera in the list: `cameras[0]`
	**/
	public var camera(get, never) : Camera;

	/**
		Camera instance that handles scene events.
		Due to Heaps structure, only one Camera can work with the Interactives.
		Contrary to rendering, event handling does not check if layer is visible for camera or not.
		Should never be null. If Camera does not belong to the Scene, it will be added with `Scene.addCamera`.
	**/
	public var interactiveCamera(default, set) : Camera;

	/**
		Set the default value for `h2d.Drawable.smooth` (default: false)
	**/
	public var defaultSmooth(get, set) : Bool;

	/**
		The scene current renderer. Can be customized.
	**/
	public var renderer(get, set) : RenderContext;

	var interactive : Array<Interactive>;
	var eventListeners : Array< hxd.Event -> Void >;
	var ctx : RenderContext;
	var window : hxd.Window;
	@:allow(h2d.Interactive)
	var events : hxd.SceneEvents;
	var shapePoint : h2d.col.Point;

	/**
		Create a new scene. A default 2D scene is already available in `hxd.App.s2d`
	**/
	public function new() {
		super(null);
		var e = h3d.Engine.getCurrent();
		ctx = new RenderContext(this);
		_cameras = [new Camera()];
		_cameras[0].scene = this;
		interactiveCamera = camera;
		width = e.width;
		height = e.height;
		viewportA = 2 / e.width;
		viewportD = 2 / e.height;
		viewportX = -1;
		viewportY = -1;
		viewportScaleX = 1;
		viewportScaleY = 1;
		offsetX = 0;
		offsetY = 0;
		interactive = new Array();
		eventListeners = new Array();
		shapePoint = new h2d.col.Point();
		window = hxd.Window.getInstance();
		posChanged = true;
	}

	inline function get_defaultSmooth() return ctx.defaultSmooth;
	inline function set_defaultSmooth(v) return ctx.defaultSmooth = v;

	@:dox(hide) @:noCompletion
	public function setEvents(events : hxd.SceneEvents) {
		this.events = events;
	}

	function get_zoom() : Int {
		return switch ( scaleMode ) {
			case Zoom(level): Std.int(level);
			default: 0;
		}
	}

	function set_zoom(v:Int) {
		scaleMode = Zoom(v);
		return v;
	}

	function set_scaleMode( v : ScaleMode ) {
		scaleMode = v;
		checkResize();
		return v;
	}

	function get_renderer() return ctx;
	function set_renderer(v) { ctx = v; return v; }

	inline function get_camera() return _cameras[0];

	inline function get_cameras() return _cameras;

	function set_interactiveCamera( cam : Camera ) {
		if ( cam == null ) throw "Interactive cammera cannot be null!";
		if ( cam.scene != this ) this.addCamera(cam);
		return interactiveCamera = cam;
	}

	/** Adds Camera to Scene camera list with optional index at which it is added. **/
	public function addCamera( cam : Camera, ?pos : Int ) {
		if ( cam.scene != null )
			cam.scene.removeCamera(cam);
		cam.scene = this;
		cam.posChanged = true;
		if ( pos != null ) _cameras.insert(pos, cam);
		else _cameras.push(cam);
	}

	/** Removes Camera from Scene camera list. Current `interactiveCamera` cannot be removed. **/
	public function removeCamera( cam : Camera ) {
		if ( cam == interactiveCamera ) throw "Current interactive Camera cannot be removed from camera list!";
		if (_cameras.remove(cam)) {
			cam.scene = null;
		}
	}

	/** Creates and returns a new Camera instance which is inserted to specified position or at the end of the camera list. **/
	public function createCamera( anchorX : Float = 0., anchorY : Float = 0., ?pos : Int ) : h2d.Camera {
		var camera = new Camera(anchorX, anchorY);
		addCamera(camera, pos);
		return camera;
	}

	/**
		Set the fixed size for the scene, will prevent automatic scene resizing when screen size changes.
	**/
	@:deprecated("setFixedSize is deprecated, use scaleMode = Strech(w, h) instead")
	public function setFixedSize( w : Int, h : Int ) {
		scaleMode = Stretch(w, h);
	}

	@:dox(hide) @:noCompletion
	public function checkResize() {
		var engine = h3d.Engine.getCurrent();

		inline function setSceneSize( w : Int, h : Int ) {
			if ( w != this.width || h != this.height ) {
				width = w;
				height = h;
				posChanged = true;
			}
		}

		inline function setScale( sx : Float, sy : Float ) {
			viewportScaleX = sx;
			viewportScaleY = sy;
		}

		inline function calcViewport( horizontal : ScaleModeAlign, vertical : ScaleModeAlign, zoom : Float ) {
			viewportA = (zoom * 2) / engine.width;
			viewportD = (zoom * 2) / engine.height;
			setScale(zoom, zoom);
			if ( horizontal == null ) horizontal = Center;
			switch ( horizontal ) {
				case Left:
					viewportX = -1;
					offsetX = 0;
				case Right:
					viewportX = 1 - (width * viewportA);
					offsetX = engine.width - width * zoom;
				default:
					// Simple `width * viewportA - 0.5` causes gaps between tiles
					viewportX = Math.floor((engine.width - width * zoom) / (zoom * 2)) * viewportA - 1.;
					offsetX = Math.floor((engine.width - width * zoom) / 2);
			}

			if ( vertical == null ) vertical = Center;
			switch ( vertical ) {
				case Top:
					viewportY = -1;
					offsetY = 0;
				case Bottom:
					viewportY = 1 - (height * viewportD);
					offsetY = engine.height - height * zoom;
				default:
					viewportY = Math.floor((engine.height - height * zoom) / (zoom * 2)) * viewportD - 1.;
					offsetY = Math.floor((engine.height - height * zoom) / 2);
			}
		}

		inline function zeroViewport() {
			viewportA = 2 / width;
			viewportD = 2 / height;
			viewportX = -1;
			viewportY = -1;
		}

		switch ( scaleMode ) {
			case Resize:
				setSceneSize(engine.width, engine.height);
				setScale(1, 1);
				zeroViewport();
			case Stretch(_width, _height):
				setSceneSize(_width, _height);
				setScale(engine.width / _width, engine.height / _height);
				zeroViewport();
			case LetterBox(_width, _height, integerScale, horizontalAlign, verticalAlign):
				setSceneSize(_width, _height);
				var zoom = Math.min(engine.width / _width, engine.height / _height);
				if ( integerScale ) {
					zoom = Std.int(zoom);
					if (zoom == 0) zoom = 1;
				}
				calcViewport(horizontalAlign, verticalAlign, zoom);
			case Fixed(_width, _height, zoom, horizontalAlign, verticalAlign):
				setSceneSize(_width, _height);
				calcViewport(horizontalAlign, verticalAlign, zoom);
			case Zoom(level):
				setSceneSize(Math.ceil(engine.width / level), Math.ceil(engine.height / level));
				setScale(level, level);
				zeroViewport();
			case AutoZoom(minWidth, minHeight, integerScaling):
				var zoom = Math.min(engine.width / minWidth, engine.height / minHeight);
				if ( integerScaling ) {
					zoom = Std.int(zoom);
					if ( zoom == 0 ) zoom = 1;
				}
				setSceneSize(Math.ceil(engine.width / zoom), Math.ceil(engine.height / zoom));
				setScale(zoom, zoom);
				zeroViewport();
		}
	}

	function get_mouseX() {
		return @:privateAccess interactiveCamera.screenXToCamera(window.mouseX, window.mouseY);
	}

	function get_mouseY() {
		return @:privateAccess interactiveCamera.screenYToCamera(window.mouseX, window.mouseY);
	}

	@:dox(hide) @:noCompletion
	public function dispatchListeners( event : hxd.Event ) {
		screenToLocal(event);
		for( l in eventListeners ) {
			l(event);
			if( !event.propagate ) break;
		}
	}

	@:dox(hide) @:noCompletion
	public function isInteractiveVisible( i : hxd.SceneEvents.Interactive ) : Bool {
		var s : Object = cast i;
		while( s != this ) {
			if( s == null || !s.visible ) return false;
			s = s.parent;
		}
		return true;
	}

	/**
		Return the topmost visible Interactive at the specific coordinates
	**/
	public function getInteractive( x : Float, y : Float ) : Interactive {
		var rx = x * matA + y * matB + absX;
		var ry = x * matC + y * matD + absY;
		var pt = shapePoint;
		for( i in interactive ) {

			var dx = rx - i.absX;
			var dy = ry - i.absY;

			var w1 = i.width * i.matA;
			var h1 = i.width * i.matC;
			var ky = h1 * dx + w1 * dy;

			// up line
			if( ky < 0 )
				continue;

			var w2 = i.height * i.matB;
			var h2 = i.height * i.matD;
			var kx = w2 * dy + h2 * dx;

			// left line
			if( kx < 0 )
				continue;

			var max = w1 * h2 - h1 * w2;

			// bottom/right
			if( ky >= max || kx >= max )
				continue;

			// check visibility
			var visible = true;
			var p : Object = i;
			while( p != null ) {
				if( !p.visible ) {
					visible = false;
					break;
				}
				p = p.parent;
			}
			if( !visible ) continue;

			if (i.shape != null) {
				pt.set((kx / max) * i.width + i.shapeX, (ky / max) * i.height + i.shapeY);
				if ( !i.shape.contains(pt) ) continue;
			}

			return i;
		}
		return null;
	}

	function screenToLocal( e : hxd.Event ) {
		interactiveCamera.eventToCamera(e);
	}

	@:dox(hide) @:noCompletion
	public function dispatchEvent( event : hxd.Event, to : hxd.SceneEvents.Interactive ) {
		var i : Interactive = cast to;
		screenToLocal(event);

		var rx = event.relX;
		var ry = event.relY;

		var dx = rx - i.absX;
		var dy = ry - i.absY;

		var w1 = i.width * i.matA;
		var h1 = i.width * i.matC;
		var ky = h1 * dx + w1 * dy;

		var w2 = i.height * i.matB;
		var h2 = i.height * i.matD;
		var kx = w2 * dy + h2 * dx;

		var max = w1 * h2 - h1 * w2;

		event.relX = (kx / max) * i.width;
		event.relY = (ky / max) * i.height;

		i.handleEvent(event);
	}

	@:dox(hide) @:noCompletion
	public function handleEvent( event : hxd.Event, last : hxd.SceneEvents.Interactive ) : hxd.SceneEvents.Interactive {
		screenToLocal(event);
		var rx = event.relX;
		var ry = event.relY;
		var index = last == null ? 0 : interactive.indexOf(cast last) + 1;
		var pt = shapePoint;
		for( idx in index...interactive.length ) {
			var i = interactive[idx];
			if( i == null ) break;

			var dx = rx - i.absX;
			var dy = ry - i.absY;

			if ( i.shape != null ) {
				// Check collision for Shape Interactive.

				pt.set(( dx * i.matD - dy * i.matC) * i.invDet + i.shapeX,
				       (-dx * i.matB + dy * i.matA) * i.invDet + i.shapeY);
				if ( !i.shape.contains(pt) ) continue;

				dx = pt.x - i.shapeX;
				dy = pt.y - i.shapeY;

			} else {
				// Check AABB for width/height Interactive.

				var w1 = i.width * i.matA;
				var h1 = i.width * i.matC;
				var ky = h1 * dx + w1 * dy;

				// up line
				if( ky < 0 )
					continue;

				var w2 = i.height * i.matB;
				var h2 = i.height * i.matD;
				var kx = w2 * dy + h2 * dx;

				// left line
				if( kx < 0 )
					continue;

				var max = w1 * h2 - h1 * w2;

				// bottom/right
				if( ky >= max || kx >= max )
					continue;

				dx = (kx / max) * i.width;
				dy = (ky / max) * i.height;
			}

			// check visibility
			var visible = true;
			var p : Object = i;
			while( p != null ) {
				if( !p.visible ) {
					visible = false;
					break;
				}
				p = p.parent;
			}
			if( !visible ) continue;

			event.relX = dx;
			event.relY = dy;

			i.handleEvent(event);

			if( event.cancel ) {
				event.cancel = false;
				event.propagate = false;
				continue;
			}

			return i;
		}
		return null;
	}

	/**
		Add an event listener that will capture all events not caught by an h2d.Interactive
	**/
	public function addEventListener( f : hxd.Event -> Void ) {
		eventListeners.push(f);
	}

	/**
		Remove a previously added event listener, return false it was not part of our event listeners.
	**/
	public function removeEventListener( f : hxd.Event -> Void ) {
		for( e in eventListeners )
			if( Reflect.compareMethods(e, f) ) {
				eventListeners.remove(e);
				return true;
			}
		return false;
	}

	/**
		Start a drag and drop operation, sending all events to `onEvent` instead of the scene until `stopDrag()` is called.
		@param	onCancel	If defined, will be called when stopDrag is called
		@param	refEvent	For touch events, only capture events that matches the reference event touchId
	**/
	public function startDrag( onEvent : hxd.Event -> Void, ?onCancel : Void -> Void, ?refEvent : hxd.Event ) {
		events.startDrag(function(e) {
			screenToLocal(e);
			onEvent(e);
		},onCancel, refEvent);
	}

	/**
		Stop the current drag and drop operation
	**/
	public function stopDrag() {
		events.stopDrag();
	}

	/**
		Get the currently focused Interactive
	**/
	public function getFocus() : Interactive {
		if( events == null )
			return null;
		var f = events.getFocus();
		if( f == null )
			return null;
		var i = hxd.impl.Api.downcast(f, h2d.Interactive);
		if( i == null )
			return null;
		return interactive[interactive.indexOf(i)];
	}

	@:allow(h2d)
	function addEventTarget(i:Interactive) {
		// sort by which is over the other in the scene hierarchy
		inline function getLevel(i:Object) {
			var lv = 0;
			while( i != null ) {
				i = i.parent;
				lv++;
			}
			return lv;
		}
		inline function indexOf(p:Object, i:Object) {
			var id = -1;
			for( k in 0...p.children.length )
				if( p.children[k] == i ) {
					id = k;
					break;
				}
			return id;
		}
		var level = getLevel(i);
		for( index in 0...interactive.length ) {
			var i1 : Object = i;
			var i2 : Object = interactive[index];
			var lv1 = level;
			var lv2 = getLevel(i2);
			var p1 : Object = i1;
			var p2 : Object = i2;
			while( lv1 > lv2 ) {
				i1 = p1;
				p1 = p1.parent;
				lv1--;
			}
			while( lv2 > lv1 ) {
				i2 = p2;
				p2 = p2.parent;
				lv2--;
			}
			while( p1 != p2 ) {
				i1 = p1;
				p1 = p1.parent;
				i2 = p2;
				p2 = p2.parent;
			}
			if( indexOf(p1,i1) > indexOf(p2,i2) ) {
				interactive.insert(index, i);
				return;
			}
		}
		interactive.push(i);
	}

	@:allow(h2d)
	function removeEventTarget(i,notify=false) {
		interactive.remove(i);
		if( notify && events != null )
			@:privateAccess events.onRemove(i);
	}

	/**
		Dispose the scene and all its children, freeing used GPU memory
	**/
	public function dispose() {
		if( allocated )
			onRemove();
		ctx.dispose();
	}

	/**
		Before render() or sync() are called, allow to set how much time has elapsed (in seconds) since the last frame in order to update scene animations.
		This is managed automatically by hxd.App
	**/
	public function setElapsedTime( v : Float ) {
		ctx.elapsedTime = v;
	}

	function drawImplTo( s : Object, t : h3d.mat.Texture ) {

		if( !t.flags.has(Target) ) throw "Can only draw to texture created with Target flag";
		var needClear = !t.flags.has(WasCleared);
		ctx.engine = h3d.Engine.getCurrent();
		ctx.engine.begin();
		ctx.globalAlpha = alpha;
		ctx.begin();
		ctx.pushTarget(t);
		if( needClear )
			ctx.engine.clear(0);
		s.drawRec(ctx);
		ctx.popTarget();
	}

	/**
		Synchronize the scene without rendering, updating all objects and animations by the given amount of time, in seconds.
	**/
	public function syncOnly( et : Float ) {
		var engine = h3d.Engine.getCurrent();
		setElapsedTime(et);
		ctx.engine = engine;
		ctx.frame++;
		ctx.time += ctx.elapsedTime;
		ctx.globalAlpha = alpha;
		sync(ctx);
	}

	/**
		Render the scene on screen. Internal usage only.
	**/
	public function render( engine : h3d.Engine ) {
		ctx.engine = engine;
		ctx.frame++;
		ctx.time += ctx.elapsedTime;
		ctx.globalAlpha = alpha;
		sync(ctx);
		if( children.length == 0 ) return;
		ctx.begin();
		ctx.drawScene();
		ctx.end();
	}

	override function sync( ctx : RenderContext ) {
		var forceCamSync = posChanged;
		if( !allocated )
			onAdd();
		super.sync(ctx);
		for ( cam in cameras ) cam.sync(ctx, forceCamSync);
	}

	override function clipBounds(ctx:RenderContext, bounds:h2d.col.Bounds)
	{
		// Scene always uses whole window surface as a filter bounds as to not clip out cameras.
		bounds.empty();
		if ( rotation == 0 ) {
			bounds.addPos(-absX, -absY);
			bounds.addPos(window.width / matA, window.height / matD);
		}
	}

	override function drawContents(ctx:RenderContext, front2back:Bool)
	{
		if( front2back ) {
			for ( cam in cameras ) {
				if ( !cam.visible ) continue;
				var i = children.length;
				var l = layerCount;
				cam.enter(ctx);
				while ( l-- > 0 ) {
					var top = l == 0 ? 0 : layersIndexes[l - 1];
					if ( cam.layerVisible(l) ) {
						while ( i >= top ) {
							children[i--].drawRec(ctx);
						}
					} else {
						i = top - 1;
					}
				}
				cam.exit(ctx);
			}
			draw(ctx);
		} else {
			draw(ctx);
			for ( cam in cameras ) {
				if ( !cam.visible ) continue;
				var i = 0;
				var l = 0;
				cam.enter(ctx);
				while ( l < layerCount ) {
					var top = layersIndexes[l++];
					if ( cam.layerVisible(l - 1) ) {
						while ( i < top ) {
							children[i++].drawRec(ctx);
						}
					} else {
						i = top;
					}
				}
				cam.exit(ctx);
			}
		}
	}

	override function onAdd() {
		checkResize();
		super.onAdd();
		window.addResizeEvent(checkResize);
	}

	override function onRemove() {
		super.onRemove();
		window.removeResizeEvent(checkResize);
	}

	/**
		Capture the scene into a texture and render the resulting Bitmap
	**/
	public function captureBitmap( ?target : Tile ) {
		var engine = h3d.Engine.getCurrent();
		if( target == null ) {
			var tex = new h3d.mat.Texture(width, height, [Target]);
			target = new Tile(tex,0, 0, width, height);
		}
		engine.begin();
		engine.setRenderZone(Std.int(target.x), Std.int(target.y), hxd.Math.ceil(target.width), hxd.Math.ceil(target.height));

		var tex = target.getTexture();
		engine.pushTarget(tex);
		var ow = width, oh = height, ova = viewportA, ovd = viewportD, ovx = viewportX, ovy = viewportY;
		width = tex.width;
		height = tex.height;
		viewportA = 2 / width;
		viewportD = 2 / height;
		viewportX = -1;
		viewportY = -1;
		posChanged = true;
		render(engine);
		engine.popTarget();

		width = ow;
		height = oh;
		viewportA = ova;
		viewportD = ovd;
		viewportX = ovx;
		viewportY = ovy;
		posChanged = true;
		engine.setRenderZone();
		engine.end();
		return new Bitmap(target);
	}


}
