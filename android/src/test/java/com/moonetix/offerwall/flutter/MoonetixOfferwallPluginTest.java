package com.moonetix.offerwall.flutter;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import android.app.Activity;
import android.content.Context;

import com.moonetix.offerwall.MoonetixError;
import com.moonetix.offerwall.MoonetixListener;
import com.moonetix.offerwall.MoonetixOptions;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import org.junit.Before;
import org.junit.Test;

public class MoonetixOfferwallPluginTest {

    private static final String APP_ID = "eeee35416ef2e85e9b4d8203";
    private static final String TOKEN = "sst_" + "A".repeat(43);

    /** Records what the plugin asks the native SDK to do. */
    private static final class FakeSdk implements MoonetixOfferwallPlugin.NativeSdk {
        final List<String> calls = new ArrayList<>();
        Context initContext;
        String initAppId;
        Activity openActivity;
        String openToken;
        MoonetixOptions openOptions;
        MoonetixListener listener;
        RuntimeException openFailure;

        @Override
        public void init(Context context, String appId) {
            calls.add("init");
            initContext = context;
            initAppId = appId;
        }

        @Override
        public void open(Activity activity, String token, MoonetixOptions options) {
            calls.add("open");
            if (openFailure != null) {
                throw openFailure;
            }
            openActivity = activity;
            openToken = token;
            openOptions = options;
        }

        @Override
        public void setListener(MoonetixListener listener) {
            calls.add(listener == null ? "setListener(null)" : "setListener");
            this.listener = listener;
        }
    }

    private FakeSdk sdk;
    private MoonetixOfferwallPlugin plugin;
    private FlutterPlugin.FlutterPluginBinding engine;
    private Context appContext;
    private Activity activity;
    private MethodChannel.Result result;

    @Before
    public void setUp() {
        sdk = new FakeSdk();
        plugin = new MoonetixOfferwallPlugin(sdk);
        appContext = mock(Context.class);
        engine = mock(FlutterPlugin.FlutterPluginBinding.class);
        when(engine.getApplicationContext()).thenReturn(appContext);
        when(engine.getBinaryMessenger()).thenReturn(mock(BinaryMessenger.class));
        activity = mock(Activity.class);
        result = mock(MethodChannel.Result.class);
    }

    private void attach() {
        plugin.onAttachedToEngine(engine);
        ActivityPluginBinding binding = mock(ActivityPluginBinding.class);
        when(binding.getActivity()).thenReturn(activity);
        plugin.onAttachedToActivity(binding);
    }

    private static Map<String, Object> openArgs() {
        Map<String, Object> args = new HashMap<>();
        args.put("token", TOKEN);
        args.put("title", null);
        args.put("toolbarColor", null);
        args.put("showLogo", true);
        return args;
    }

    @Test
    public void attachSetsTheEventListener() {
        plugin.onAttachedToEngine(engine);
        assertTrue(sdk.listener instanceof MoonetixOfferwallPlugin.EventForwarder);
    }

    @Test
    public void initPassesTheAppIdAndApplicationContext() {
        attach();
        Map<String, Object> args = new HashMap<>();
        args.put("appId", APP_ID);
        plugin.onMethodCall(new MethodCall("init", args), result);
        assertEquals(APP_ID, sdk.initAppId);
        assertSame(appContext, sdk.initContext);
        verify(result).success(null);
    }

    @Test
    public void initWithoutAnAppIdReportsInvalidAppId() {
        attach();
        plugin.onMethodCall(new MethodCall("init", new HashMap<String, Object>()), result);
        assertFalse(sdk.calls.contains("init"));
        verify(result).error("INVALID_APP_ID", MoonetixOfferwallPlugin.INVALID_APP_ID_MESSAGE, null);
    }

    @Test
    public void openPassesTheTokenAndDefaultOptions() {
        attach();
        plugin.onMethodCall(new MethodCall("open", openArgs()), result);
        assertSame(activity, sdk.openActivity);
        assertEquals(TOKEN, sdk.openToken);
        assertEquals(new MoonetixOptions(null, null, true), sdk.openOptions);
        verify(result).success(null);
    }

    @Test
    public void openSetsOurListenerBeforeOpening() {
        attach();
        sdk.calls.clear();
        plugin.onMethodCall(new MethodCall("open", openArgs()), result);
        assertEquals(List.of("setListener", "open"), sdk.calls);
    }

    @Test
    public void openMapsTitleColorAndLogo() {
        attach();
        Map<String, Object> args = openArgs();
        args.put("title", "Earn coins");
        args.put("toolbarColor", 0xFF0B5FFFL);
        args.put("showLogo", false);
        plugin.onMethodCall(new MethodCall("open", args), result);
        assertEquals(new MoonetixOptions("Earn coins", 0xFF0B5FFF, false), sdk.openOptions);
    }

    @Test
    public void optionsAcceptSmallColorsSentAsInteger() {
        Map<String, Object> args = new HashMap<>();
        args.put("toolbarColor", 0x00112233);
        assertEquals(Integer.valueOf(0x00112233), MoonetixOfferwallPlugin.optionsFrom(args).getToolbarColor());
    }

    @Test
    public void optionsDefaultsWhenArgumentsAreMissing() {
        MoonetixOptions options = MoonetixOfferwallPlugin.optionsFrom(null);
        assertNull(options.getTitle());
        assertNull(options.getToolbarColor());
        assertTrue(options.getShowLogo());
    }

    @Test
    public void openWithoutActivityReportsAnError() {
        plugin.onAttachedToEngine(engine);
        plugin.onMethodCall(new MethodCall("open", openArgs()), result);
        assertFalse(sdk.calls.contains("open"));
        verify(result).error("UNKNOWN", MoonetixOfferwallPlugin.NO_ACTIVITY_MESSAGE, null);
    }

    @Test
    public void openAfterActivityDetachReportsAnError() {
        attach();
        plugin.onDetachedFromActivity();
        plugin.onMethodCall(new MethodCall("open", openArgs()), result);
        assertFalse(sdk.calls.contains("open"));
        verify(result).error("UNKNOWN", MoonetixOfferwallPlugin.NO_ACTIVITY_MESSAGE, null);
    }

    @Test
    public void openUsesTheActivityAfterAConfigChange() {
        attach();
        plugin.onDetachedFromActivityForConfigChanges();
        Activity recreated = mock(Activity.class);
        ActivityPluginBinding binding = mock(ActivityPluginBinding.class);
        when(binding.getActivity()).thenReturn(recreated);
        plugin.onReattachedToActivityForConfigChanges(binding);
        plugin.onMethodCall(new MethodCall("open", openArgs()), result);
        assertSame(recreated, sdk.openActivity);
    }

    @Test
    public void openWithoutTokenReportsInvalidToken() {
        attach();
        Map<String, Object> args = openArgs();
        args.remove("token");
        plugin.onMethodCall(new MethodCall("open", args), result);
        assertFalse(sdk.calls.contains("open"));
        verify(result).error("INVALID_TOKEN", MoonetixOfferwallPlugin.INVALID_TOKEN_MESSAGE, null);
    }

    @Test
    public void openFailureIsReportedWithoutTheToken() {
        attach();
        sdk.openFailure = new IllegalStateException(TOKEN);
        plugin.onMethodCall(new MethodCall("open", openArgs()), result);
        verify(result).error("UNKNOWN", "Could not open the offerwall: IllegalStateException.", null);
        verify(result, never()).success(any());
    }

    @Test
    public void unknownMethodIsNotImplemented() {
        attach();
        plugin.onMethodCall(new MethodCall("getPlatformVersion", null), result);
        verify(result).notImplemented();
    }

    @Test
    public void detachClearsOnlyOurOwnListener() {
        attach();
        plugin.onDetachedFromEngine(engine);
        assertEquals("setListener(null)", sdk.calls.get(sdk.calls.size() - 1));
        assertNull(sdk.listener);
    }

    @Test
    public void detachKeepsTheListenerOfANewerEngine() {
        FakeSdk shared = sdk;
        MoonetixOfferwallPlugin first = new MoonetixOfferwallPlugin(shared);
        MoonetixOfferwallPlugin second = new MoonetixOfferwallPlugin(shared);
        first.onAttachedToEngine(engine);
        second.onAttachedToEngine(engine);
        MoonetixListener secondListener = shared.listener;
        first.onDetachedFromEngine(engine);
        assertSame(secondListener, shared.listener);
        second.onDetachedFromEngine(engine);
        assertNull(shared.listener);
    }

    @Test
    public void errorMapCarriesCodeAndMessage() {
        Map<String, Object> map = MoonetixOfferwallPlugin.errorMap(
                new MoonetixError(MoonetixError.Code.TOKEN_EXPIRED_OR_USED, "expired"));
        assertEquals("error", map.get("type"));
        assertEquals("TOKEN_EXPIRED_OR_USED", map.get("code"));
        assertEquals("expired", map.get("message"));
    }

    @Test
    public void forwarderSendsEventsToDart() {
        MethodChannel channel = mock(MethodChannel.class);
        MoonetixOfferwallPlugin.EventForwarder forwarder = new MoonetixOfferwallPlugin.EventForwarder(channel);
        forwarder.onOpened();
        forwarder.onClosed();
        forwarder.onError(new MoonetixError(MoonetixError.Code.NETWORK, "offline"));
        verify(channel).invokeMethod("event", MoonetixOfferwallPlugin.eventMap("opened"));
        verify(channel).invokeMethod("event", MoonetixOfferwallPlugin.eventMap("closed"));
        Map<String, Object> error = new HashMap<>();
        error.put("type", "error");
        error.put("code", "NETWORK");
        error.put("message", "offline");
        verify(channel).invokeMethod(eq("event"), eq(error));
        verify(channel, never()).invokeMethod(anyString(), isNull());
    }
}
