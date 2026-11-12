package com.moonetix.offerwall.flutter;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.moonetix.offerwall.Moonetix;
import com.moonetix.offerwall.MoonetixError;
import com.moonetix.offerwall.MoonetixListener;
import com.moonetix.offerwall.MoonetixOptions;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Flutter plugin that forwards {@code Moonetix.init} and {@code Moonetix.open} from Dart to the
 * native Moonetix Android SDK ({@code com.moonetix:offerwall}) and sends its events back.
 *
 * <p>The session token only passes through memory. It is never logged.
 */
public final class MoonetixOfferwallPlugin
        implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    static final String CHANNEL = "com.moonetix/offerwall";

    static final String NO_ACTIVITY_MESSAGE =
            "Moonetix.open() needs a visible screen. Call it while your app is in the foreground.";
    static final String INVALID_APP_ID_MESSAGE =
            "The app ID passed to Moonetix.init() is invalid. It must be the 24-character lowercase hex ID from your Moonetix dashboard.";
    static final String INVALID_TOKEN_MESSAGE =
            "The session token is malformed. Pass the \"token\" value returned by POST /v1/session.";

    /** The calls this plugin makes into the native SDK, so tests can replace them. */
    interface NativeSdk {
        void init(@NonNull Context context, @NonNull String appId);

        void open(@NonNull Activity activity, @NonNull String token, @NonNull MoonetixOptions options);

        void setListener(@Nullable MoonetixListener listener);
    }

    static final NativeSdk MOONETIX_SDK = new NativeSdk() {
        @Override
        public void init(@NonNull Context context, @NonNull String appId) {
            Moonetix.init(context, appId);
        }

        @Override
        public void open(@NonNull Activity activity, @NonNull String token, @NonNull MoonetixOptions options) {
            Moonetix.open(activity, token, options);
        }

        @Override
        public void setListener(@Nullable MoonetixListener listener) {
            Moonetix.setListener(listener);
        }
    };

    // The native SDK keeps one listener for the whole process; this is the one we set last.
    private static MoonetixListener activeListener;

    private final NativeSdk sdk;
    @Nullable private MethodChannel channel;
    @Nullable private Context appContext;
    @Nullable private Activity activity;
    @Nullable private MoonetixListener forwarder;

    public MoonetixOfferwallPlugin() {
        this(MOONETIX_SDK);
    }

    MoonetixOfferwallPlugin(@NonNull NativeSdk sdk) {
        this.sdk = sdk;
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        appContext = binding.getApplicationContext();
        MethodChannel ch = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        ch.setMethodCallHandler(this);
        channel = ch;
        forwarder = new EventForwarder(ch);
        useOurListener();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
        }
        synchronized (MoonetixOfferwallPlugin.class) {
            if (forwarder != null && activeListener == forwarder) {
                sdk.setListener(null);
                activeListener = null;
            }
        }
        channel = null;
        forwarder = null;
        appContext = null;
        activity = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "init":
                handleInit(call, result);
                break;
            case "open":
                handleOpen(call, result);
                break;
            default:
                result.notImplemented();
        }
    }

    private void handleInit(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        Object appId = call.argument("appId");
        if (!(appId instanceof String)) {
            result.error("INVALID_APP_ID", INVALID_APP_ID_MESSAGE, null);
            return;
        }
        Context context = appContext;
        if (context == null) {
            result.error("UNKNOWN", "The Moonetix plugin is not attached to Flutter.", null);
            return;
        }
        sdk.init(context, (String) appId);
        result.success(null);
    }

    private void handleOpen(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        Object token = call.argument("token");
        if (!(token instanceof String)) {
            result.error("INVALID_TOKEN", INVALID_TOKEN_MESSAGE, null);
            return;
        }
        Activity current = activity;
        if (current == null) {
            result.error("UNKNOWN", NO_ACTIVITY_MESSAGE, null);
            return;
        }
        // The engine that opens the offerwall receives its events.
        useOurListener();
        try {
            sdk.open(current, (String) token, optionsFrom(call.arguments));
        } catch (RuntimeException e) {
            result.error("UNKNOWN", "Could not open the offerwall: " + e.getClass().getSimpleName() + ".", null);
            return;
        }
        result.success(null);
    }

    private void useOurListener() {
        MoonetixListener ours = forwarder;
        if (ours == null) {
            return;
        }
        synchronized (MoonetixOfferwallPlugin.class) {
            sdk.setListener(ours);
            activeListener = ours;
        }
    }

    /** Maps the Dart options ({@code title}, {@code toolbarColor} as ARGB, {@code showLogo}). */
    @NonNull
    static MoonetixOptions optionsFrom(@Nullable Object arguments) {
        Map<?, ?> args = arguments instanceof Map ? (Map<?, ?>) arguments : new HashMap<>();
        Object title = args.get("title");
        Object color = args.get("toolbarColor");
        Object showLogo = args.get("showLogo");
        return new MoonetixOptions(
                title instanceof String ? (String) title : null,
                // Dart sends ARGB values above 0x7FFFFFFF as a Long; intValue() keeps the 32 bits.
                color instanceof Number ? Integer.valueOf(((Number) color).intValue()) : null,
                !(showLogo instanceof Boolean) || (Boolean) showLogo);
    }

    @NonNull
    static Map<String, Object> eventMap(@NonNull String type) {
        Map<String, Object> map = new HashMap<>();
        map.put("type", type);
        return map;
    }

    @NonNull
    static Map<String, Object> errorMap(@NonNull MoonetixError error) {
        Map<String, Object> map = eventMap("error");
        map.put("code", error.getCode().name());
        map.put("message", error.getMessage());
        return map;
    }

    /** Sends the native SDK events to Dart. The SDK calls it on the main thread. */
    static final class EventForwarder implements MoonetixListener {
        private final MethodChannel channel;

        EventForwarder(@NonNull MethodChannel channel) {
            this.channel = channel;
        }

        @Override
        public void onOpened() {
            channel.invokeMethod("event", eventMap("opened"));
        }

        @Override
        public void onClosed() {
            channel.invokeMethod("event", eventMap("closed"));
        }

        @Override
        public void onError(@NonNull MoonetixError error) {
            channel.invokeMethod("event", errorMap(error));
        }
    }
}
