<?php
    /**
     * Wires the global Lexis engine into Laravel: a singleton
     * bound to the container, and a @lex Blade directive as shorthand.
     */
    namespace App\Providers;

    use Illuminate\Support\Facades\Blade;
    use Illuminate\Support\ServiceProvider;
    
    class LexisServiceProvider extends ServiceProvider {
        public function register(): void {
            /**
             * Register Lexis as a singleton: one instance per request,
             * build once from the current app locale and the "lang/lexis" directory.
             */
            if(!class_exists(\Lexis::class)) {
                /**
                 * Defensive load: cover deploys where composer dump-autoload
                 * wasn't run after adding Lexis.php to autoload.files.
                 */
                require_once app_path('Support/Lexis/Lexis.php');
            }

            $this->app->singleton(\Lexis::class, function($app) {
                return new \Lexis(
                    lang_path('lexis'),
                    $app->getLocale(),
                    config('app.fallback_locale', 'en')
                );
            });
        }

        public function boot(): void {
            /**
             * Register the @lex Blade directive once all providers are booted.
             * Usage in views: @lex('welcome', $user->name)
             */
            Blade::directive('lex', function (string $expression) {
                return "<?php echo e(app(\Lexis::class)->get({$expression})); ?>";
            });
        }
    }