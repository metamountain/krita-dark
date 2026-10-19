"""Dark Icons: darkens Krita's fixed light-grey icons.

Every QAbstractButton / QAction icon in the main window gets a black overlay
(alpha preserved). Set DIM to taste: 0 = untouched, 255 = black.
"""
from krita import Extension, Krita
from PyQt6.QtCore import QObject, QEvent, QSize, QTimer, Qt
from PyQt6.QtGui import QAction, QColor, QIcon, QPainter, QPixmap
from PyQt6.QtWidgets import QAbstractButton, QAbstractItemView, QApplication, QWidget

DIM = 120
# Brush preset thumbnails ship with a light grey/white background. Darkening
# the preset lists keeps their colors but turns the background dark.
DIM_PRESETS = True
PRESET_DIM = 150  # 0 = untouched, 255 = black
PRESET_VIEWS = ("KisResourceItemListView",)
SIZES = (16, 22, 24, 32, 48, 64)
_FLAG = "_dark_icons_done"
# Window title bar / frame (Windows 11 only). RGB.
FRAME_COLOR = (15, 15, 15)
FRAME_TEXT = (118, 118, 118)


def _color_frame(widget):
    """Paint the native title bar and border via DWM (Windows 11). Returns HRESULTs."""
    import ctypes
    hwnd = int(widget.winId())
    dwm = ctypes.windll.dwmapi
    dwm.DwmSetWindowAttribute.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_void_p, ctypes.c_uint]

    def put(attr, value):
        val = ctypes.c_uint(value)
        return dwm.DwmSetWindowAttribute(hwnd, attr, ctypes.byref(val), 4)

    def rgb(c):
        return c[0] | (c[1] << 8) | (c[2] << 16)  # COLORREF 0x00BBGGRR

    return [put(20, 1), put(19, 1), put(35, rgb(FRAME_COLOR)), put(34, rgb(FRAME_COLOR)), put(36, rgb(FRAME_TEXT))]


def _dim_pixmap(pm):
    out = QPixmap(pm)
    p = QPainter(out)
    p.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceAtop)
    p.fillRect(out.rect(), QColor(0, 0, 0, DIM))
    p.end()
    return out


def _dim_icon(icon):
    new = QIcon()
    for mode in (QIcon.Mode.Normal, QIcon.Mode.Disabled, QIcon.Mode.Active, QIcon.Mode.Selected):
        for state in (QIcon.State.Off, QIcon.State.On):
            for s in SIZES:
                pm = icon.pixmap(QSize(s, s), mode, state)
                if not pm.isNull():
                    new.addPixmap(_dim_pixmap(pm), mode, state)
    return new


class _Veil(QWidget):
    """Transparent black layer over a view's viewport (mouse passes through).

    Child of the view itself, not of the viewport: scrolling moves the
    viewport's children, which would let light brushes show at the edges.
    """

    def __init__(self, view):
        super().__init__(view)
        self._view = view
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
        self.setAttribute(Qt.WidgetAttribute.WA_NoSystemBackground)
        view.installEventFilter(self)
        view.viewport().installEventFilter(self)
        self._fit()
        self.show()
        self.raise_()

    def _fit(self):
        self.setGeometry(self._view.viewport().geometry())

    def eventFilter(self, obj, ev):
        if ev.type() in (QEvent.Type.Resize, QEvent.Type.Show, QEvent.Type.Move, QEvent.Type.LayoutRequest):
            self._fit()
            self.raise_()
        return False

    def paintEvent(self, ev):
        p = QPainter(self)
        p.fillRect(self.rect(), QColor(0, 0, 0, PRESET_DIM))
        p.end()


class _Dimmer(QObject):
    def __init__(self):
        super().__init__()
        self._seen = set()  # icon cache keys we produced or already handled
        self._timer = QTimer(self)
        self._timer.timeout.connect(self.scan)
        self._timer.start(1500)

    def _fix(self, obj):
        icon = obj.icon()
        if icon.isNull():
            return
        key = icon.cacheKey()
        if key in self._seen:
            return
        new = _dim_icon(icon)
        self._seen.add(key)
        self._seen.add(new.cacheKey())
        obj.setIcon(new)

    def scan(self):
        win = Krita.instance().activeWindow()
        qwin = win.qwindow() if win else None
        if qwin is None:
            return
        try:
            res = _color_frame(qwin)  # repeated: Qt may reset the frame when the window changes
        except Exception as e:
            res = repr(e)
        if res != getattr(self, '_frame_res', None):
            self._frame_res = res
            import os
            try:
                with open(os.path.join(os.path.dirname(__file__), "frame.log"), "w") as f:
                    f.write(str(res))
            except OSError:
                pass
        for b in qwin.findChildren(QAbstractButton):
            self._fix(b)
        for a in qwin.findChildren(QAction):
            self._fix(a)
        if DIM_PRESETS:
            for v in qwin.findChildren(QAbstractItemView):
                self._dim_view(v)
        self._log_classes(qwin)

    def _dim_view(self, view):
        if view.property("_dark_inv") or view.metaObject().className() not in PRESET_VIEWS:
            return
        view.setProperty("_dark_inv", True)
        self._veils = getattr(self, '_veils', []) + [_Veil(view)]

    def _log_classes(self, qwin):
        # Debug aid: lists item-view class names so PRESET_VIEWS can be corrected.
        if getattr(self, "_logged", False):
            return
        self._logged = True
        import os
        names = sorted({v.metaObject().className() for v in qwin.findChildren(QAbstractItemView)})
        try:
            with open(os.path.join(os.path.dirname(__file__), "views.log"), "w") as f:
                f.write(chr(10).join(names))
        except OSError:
            pass

    def eventFilter(self, obj, ev):
        if ev.type() == QEvent.Type.Show and isinstance(obj, QAbstractButton):
            QTimer.singleShot(0, lambda o=obj: self._fix(o))
        return False


class DarkIcons(Extension):
    def __init__(self, parent):
        super().__init__(parent)

    def setup(self):
        pass

    def createActions(self, window):
        if getattr(Krita, _FLAG, False):
            return
        setattr(Krita, _FLAG, True)
        self._dimmer = _Dimmer()
        QApplication.instance().installEventFilter(self._dimmer)
        QTimer.singleShot(1500, self._dimmer.scan)


Krita.instance().addExtension(DarkIcons(Krita.instance()))
